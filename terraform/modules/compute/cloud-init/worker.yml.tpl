#cloud-config
package_update: true
package_upgrade: false
package_reboot_if_required: false

packages:
  - git
  - curl
  - wget
  - nano
  - htop
  - jq
  - iptables
  - iproute-tc

write_files:
  - path: /usr/local/bin/setup-k0s-worker.sh
    permissions: "0755"
    content: |
      #!/bin/bash
      set -euo pipefail

      echo "=== Starting K0s Worker Setup ==="

      # Download and install k0s
      echo "Downloading k0s..."
      curl -sSLf https://get.k0s.sh | sudo sh

      # Create directory for join token
      mkdir -p /tmp

      echo "=== K0s Worker Ready for Join ==="
      echo "Worker will be joined by Terraform automation"

  - path: /usr/local/bin/install-tailscale.sh
    permissions: "0755"
    content: |
      #!/bin/bash
      set -euo pipefail

      echo "=== Installing Tailscale ==="

      # Check and handle SELinux for Tailscale
      echo "Checking SELinux status..."
      if command -v getenforce >/dev/null 2>&1; then
        SELINUX_STATUS=$(getenforce)
        echo "SELinux status: $SELINUX_STATUS"
        
        if [ "$SELINUX_STATUS" = "Enforcing" ]; then
          echo "SELinux is enforcing, configuring for Tailscale..."
          
          # Allow SSH connections through non-standard interfaces
          setsebool -P ssh_sysadm_login 1 2>/dev/null || echo "Could not set ssh_sysadm_login"
          setsebool -P nis_enabled 1 2>/dev/null || echo "Could not set nis_enabled"
          
          # Allow network connections
          setsebool -P domain_kernel_load_modules 1 2>/dev/null || echo "Could not set domain_kernel_load_modules"
          
          # Set SELinux to permissive mode temporarily for setup
          echo "Setting SELinux to permissive mode for Tailscale setup..."
          setenforce 0 || echo "Could not set SELinux to permissive"
          
          echo "SELinux configuration for Tailscale completed"
        fi
      else
        echo "SELinux not available"
      fi

      # Install Tailscale
      curl -fsSL https://tailscale.com/install.sh | sh

      # Start Tailscale with provided auth key
      if [ -n "$${TAILSCALE_AUTH_KEY}" ]; then
        echo "Starting Tailscale..."
        if [ -n "$${HOSTNAME}" ]; then
          tailscale up --authkey="$${TAILSCALE_AUTH_KEY}" --hostname="$${HOSTNAME}" --accept-dns=false
        else
          echo "ERROR: HOSTNAME not provided"
          exit 1
        fi
        echo "Tailscale started successfully"
        
        # Fix DNS configuration to prevent conflicts
        echo "Configuring DNS to prevent conflicts..."
        # Backup original resolv.conf if it doesn't exist
        if [ ! -f /etc/resolv.conf.backup ]; then
          cp /etc/resolv.conf /etc/resolv.conf.backup 2>/dev/null || true
        fi
        
        # Ensure we have proper DNS servers
        if ! grep -q "100.100.100.100" /etc/resolv.conf; then
          echo "nameserver 100.100.100.100" >> /etc/resolv.conf
        fi
        if ! grep -q "8.8.8.8" /etc/resolv.conf; then
          echo "nameserver 8.8.8.8" >> /etc/resolv.conf
        fi
        
      else
        echo "ERROR: TAILSCALE_AUTH_KEY not provided"
        exit 1
      fi

      echo "=== Tailscale Installation Complete ==="

runcmd:
  # Set hostname first  
  - |
    echo "Setting hostname to: ${hostname}"
    hostnamectl set-hostname ${hostname}
    echo "${hostname}" > /etc/hostname

  # Setup Tailscale for connectivity
  - |
    export TAILSCALE_AUTH_KEY="${tailscale_auth_key}"
    export HOSTNAME="${hostname}"
    
    echo "Setting up Tailscale with hostname: $HOSTNAME"
    echo "Auth key length: $${#TAILSCALE_AUTH_KEY}"
    
    if [ -z "$TAILSCALE_AUTH_KEY" ] || [ "$TAILSCALE_AUTH_KEY" = "null" ]; then
      echo "ERROR: Failed to retrieve TAILSCALE_AUTH_KEY"
      exit 1
    fi
    
    if [ -z "$HOSTNAME" ] || [ "$HOSTNAME" = "null" ]; then
      echo "ERROR: Failed to retrieve HOSTNAME"
      exit 1
    fi
    
    /usr/local/bin/install-tailscale.sh

  # Configure firewall for K0s
  - |
    echo "Configuring firewall for worker node..."
    if systemctl is-enabled firewalld >/dev/null 2>&1; then
      # Allow traffic from private subnet and pod networks
      sudo firewall-cmd --permanent --add-source=10.0.1.0/24
      sudo firewall-cmd --permanent --add-source=10.244.0.0/16
      sudo firewall-cmd --permanent --add-source=10.96.0.0/12
      
      # Allow worker ports
      sudo firewall-cmd --permanent --add-port=10250/tcp
      sudo firewall-cmd --permanent --add-port=8132/tcp
      sudo firewall-cmd --permanent --add-port=179/tcp
      sudo firewall-cmd --permanent --add-service=ssh
      
      sudo firewall-cmd --reload
    fi

  # Setup Tailscale
  - /usr/local/bin/install-tailscale.sh

  # Setup k0s worker (ready for join)
  - /usr/local/bin/setup-k0s-worker.sh

final_message: "K0s worker node ready for ${environment} environment!"

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

      # Install Tailscale
      curl -fsSL https://tailscale.com/install.sh | sh

      # Start Tailscale
      echo "Starting Tailscale with hostname: ${hostname}"
      sudo tailscale up --authkey="${tailscale_auth_key}" --hostname="${hostname}" --accept-dns=false

      echo "=== Tailscale Installation Complete ==="

runcmd:
  # Set hostname
  - hostnamectl set-hostname ${hostname}
  - echo "${hostname}" > /etc/hostname

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

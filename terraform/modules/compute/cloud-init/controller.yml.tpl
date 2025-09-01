#cloud-config
package_update: true
package_upgrade: false
package_reboot_if_required: false

# Set hostname properly using cloud-init
echo  "1st check Current hostname: $(hostname)"
hostname: ${hostname}
echo "Expected hostname: ${hostname}"
preserve_hostname: true

packages:
  - git
  - curl
  - wget
  - nano
  - htop
  - jq
  - iptables
  - iproute-tc
  - policycoreutils-python-utils

write_files:
  - path: /usr/local/bin/setup-k0s-controller.sh
    permissions: "0755"
    content: |
      #!/bin/bash
      set -euo pipefail

      echo "=== Starting K0s Controller Setup ==="

      # Download and install k0s
      echo "Downloading k0s..."
      curl -sSLf https://get.k0s.sh | sudo sh

      # Create k0s configuration directory
      mkdir -p /etc/k0s

      # Get the primary IP address for binding
      PRIMARY_IP=$(hostname -I | awk '{print $1}')
      echo "Using primary IP for K0s API: $PRIMARY_IP"
      
      # Create k0s config with environment-specific settings
      cat > /etc/k0s/k0s.yaml <<EOCONFIG
      apiVersion: k0s.k0sproject.io/v1beta1
      kind: ClusterConfig
      metadata:
        name: k0s-cluster-${environment}
      spec:
        api:
          address: $PRIMARY_IP
          port: 6443
        storage:
          type: etcd
        network:
          provider: kuberouter
          podCIDR: 10.244.0.0/16
          serviceCIDR: 10.96.0.0/12
        telemetry:
          enabled: false
        extensions:
          storage:
            create_default_storage_class: true
      EOCONFIG

      # Install k0s as controller
      echo "Installing k0s controller..."
      k0s install controller --config /etc/k0s/k0s.yaml

      # Start k0s
      echo "Starting k0s..."
      systemctl daemon-reload
      systemctl enable k0scontroller
      systemctl start k0scontroller

      # Wait for k0s to be ready
      echo "Waiting for k0s to be ready..."
      for i in {1..24}; do
        if k0s kubectl get nodes 2>/dev/null; then
          echo "K0s API server is ready!"
          break
        fi
        echo "Waiting for API server... (attempt $i/24)"
        sleep 5
      done
      
      # Verify API server is responding
      if ! k0s kubectl get nodes 2>/dev/null; then
        echo "ERROR: K0s API server failed to start properly"
        systemctl status k0scontroller --no-pager -l
        exit 1
      fi

      # Create worker join tokens
      echo "Creating worker join tokens..."
      k0s token create --role=worker --expiry=48h > /tmp/worker-token.txt

      # Setup kubectl for opc user
      echo "Setting up kubectl for opc user..."
      mkdir -p /home/opc/.kube
      k0s kubeconfig admin > /home/opc/.kube/config
      chown -R opc:opc /home/opc/.kube

      # Create kubectl aliases
      echo "alias kubectl='k0s kubectl'" >> /home/opc/.bashrc
      echo "alias k='k0s kubectl'" >> /home/opc/.bashrc

      # Create namespaces for applications
      echo "Creating application namespaces..."
      k0s kubectl create namespace webserver || true
      k0s kubectl create namespace cloudflare-tunnel || true
      k0s kubectl create namespace monitoring || true

      # Apply default storage class
      k0s kubectl apply -f - <<'EOF'
      apiVersion: storage.k8s.io/v1
      kind: StorageClass
      metadata:
        name: local-path
        annotations:
          storageclass.kubernetes.io/is-default-class: "true"
      provisioner: kubernetes.io/no-provisioner
      volumeBindingMode: WaitForFirstConsumer
      EOF

      echo "=== K0s Controller Setup Complete ==="

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
  # Verify hostname was set correctly by cloud-init
  - |
    echo "Verifying hostname configuration..."
    echo "Current hostname: $(hostname)"
    echo "Expected hostname: ${hostname}"
    
    # Disable NetworkManager hostname setting to prevent future overrides
    if [ -f /etc/NetworkManager/NetworkManager.conf ]; then
      echo -e "\n[main]\nhostname-mode=none" >> /etc/NetworkManager/NetworkManager.conf
      systemctl restart NetworkManager || true
    fi

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
    echo "Configuring firewall for cluster communication..."
    if systemctl is-enabled firewalld >/dev/null 2>&1; then
      # Allow traffic from private subnet and pod networks
      sudo firewall-cmd --permanent --add-source=10.0.1.0/24
      sudo firewall-cmd --permanent --add-source=10.244.0.0/16
      sudo firewall-cmd --permanent --add-source=10.96.0.0/12
      
      # Allow K0s ports
      sudo firewall-cmd --permanent --add-port=6443/tcp
      sudo firewall-cmd --permanent --add-port=9443/tcp
      sudo firewall-cmd --permanent --add-port=10250/tcp
      sudo firewall-cmd --permanent --add-port=2379-2380/tcp
      sudo firewall-cmd --permanent --add-port=8132/tcp
      sudo firewall-cmd --permanent --add-port=8133/tcp
      sudo firewall-cmd --permanent --add-port=179/tcp
      sudo firewall-cmd --permanent --add-service=ssh
      
      sudo firewall-cmd --reload
    fi

  # Wait for Tailscale to be ready
  - |
    for i in {1..30}; do
      if tailscale status >/dev/null 2>&1; then
        echo "Tailscale is connected!"
        break
      fi
      sleep 1
    done

  # Setup k0s controller
  - /usr/local/bin/setup-k0s-controller.sh

final_message: "K0s controller node ready for ${environment} environment!"

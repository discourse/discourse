#!/bin/bash
set -e

# Discourse AWS EC2 Bootstrap Script
# This script is executed when the EC2 instance first boots

# Log all output
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "========================================="
echo "Discourse AWS Bootstrap Starting"
echo "========================================="
echo "Deployment Mode: ${deployment_mode}"
echo "Domain: ${domain_name}"
echo "Timestamp: $(date)"
echo "========================================="

# Update system
echo "Updating system packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y

# Install required packages
echo "Installing prerequisites..."
apt-get install -y \
    git \
    curl \
    wget \
    ca-certificates \
    gnupg \
    lsb-release \
    fail2ban \
    unattended-upgrades

# Configure automatic security updates
echo "Configuring automatic security updates..."
dpkg-reconfigure -plow unattended-upgrades

# Install Docker
echo "Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
usermod -aG docker ubuntu

# Enable and start Docker
systemctl enable docker
systemctl start docker

# Configure fail2ban
echo "Configuring fail2ban..."
systemctl enable fail2ban
systemctl start fail2ban

# Clone Discourse Docker repository
echo "Cloning Discourse Docker repository..."
if [ ! -d "/var/discourse" ]; then
    git clone https://github.com/discourse/discourse_docker.git /var/discourse
    cd /var/discourse
    chmod 700 containers
else
    echo "Discourse already cloned, updating..."
    cd /var/discourse
    git pull
fi

# Create app.yml configuration
echo "Creating Discourse configuration..."
cat > /var/discourse/containers/app.yml <<'EOF'
templates:
  - "templates/postgres.template.yml"
  - "templates/redis.template.yml"
  - "templates/web.template.yml"
  - "templates/web.ratelimited.template.yml"
  - "templates/web.ssl.template.yml"
  - "templates/web.letsencrypt.ssl.template.yml"

expose:
  - "80:80"
  - "443:443"

params:
  db_default_text_search_config: "pg_catalog.english"
  db_shared_buffers: "256MB"
  db_work_mem: "40MB"

env:
  LANG: en_US.UTF-8
  DISCOURSE_DEFAULT_LOCALE: en
  DISCOURSE_HOSTNAME: '${domain_name}'
  DISCOURSE_DEVELOPER_EMAILS: '${admin_email}'

  # Email Configuration
  DISCOURSE_SMTP_ADDRESS: ${smtp_address}
  DISCOURSE_SMTP_PORT: ${smtp_port}
  DISCOURSE_SMTP_USER_NAME: ${smtp_username}
  DISCOURSE_SMTP_PASSWORD: '${smtp_password}'
  DISCOURSE_SMTP_ENABLE_START_TLS: true
  DISCOURSE_SMTP_AUTHENTICATION: login

  # S3 Configuration for uploads
  DISCOURSE_USE_S3: true
  DISCOURSE_S3_REGION: ${s3_region}
  DISCOURSE_S3_BUCKET: ${s3_bucket}
  DISCOURSE_S3_BACKUP_BUCKET: ${s3_bucket}
  DISCOURSE_BACKUP_LOCATION: s3

%{ if deployment_mode == "production" ~}
  # External Database Configuration (RDS)
  DISCOURSE_DB_HOST: ${db_host}
  DISCOURSE_DB_NAME: ${db_name}
  DISCOURSE_DB_USERNAME: ${db_username}
  DISCOURSE_DB_PASSWORD: '${db_password}'
  DISCOURSE_DB_POOL: 25

  # External Redis Configuration (ElastiCache)
  DISCOURSE_REDIS_HOST: ${redis_host}
  DISCOURSE_REDIS_PORT: 6379
%{ endif ~}

volumes:
  - volume:
      host: /var/discourse/shared/standalone
      guest: /shared
  - volume:
      host: /var/discourse/shared/standalone/log/var-log
      guest: /var/log

hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - git clone https://github.com/discourse/docker_manager.git

run:
  - exec: echo "Installation complete"
EOF

# Set permissions
chmod 600 /var/discourse/containers/app.yml

%{ if deployment_mode == "simple" ~}
# Bootstrap Discourse (Simple mode - first time setup)
echo "Bootstrapping Discourse (this may take 10-15 minutes)..."
cd /var/discourse

# Check if already bootstrapped
if [ ! -d "/var/discourse/shared/standalone/postgres" ]; then
    ./launcher bootstrap app
    ./launcher start app
    echo "Discourse bootstrap complete!"
else
    echo "Discourse already bootstrapped, starting..."
    ./launcher start app
fi
%{ else ~}
# Production mode - bootstrap will be done manually after database is ready
echo "Production mode detected. Discourse configuration created."
echo "Please bootstrap manually after verifying database connectivity:"
echo "  cd /var/discourse && ./launcher bootstrap app"
%{ endif ~}

# Create status check endpoint
echo "Creating health check..."
mkdir -p /var/www/html
cat > /var/www/html/health.html <<'HEALTHEOF'
OK
HEALTHEOF

# Install CloudWatch agent (optional but recommended)
echo "Installing CloudWatch agent..."
wget -q https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i amazon-cloudwatch-agent.deb || true
rm amazon-cloudwatch-agent.deb

# Create CloudWatch config
cat > /opt/aws/amazon-cloudwatch-agent/etc/cloudwatch-config.json <<'CWEOF'
{
  "metrics": {
    "namespace": "Discourse",
    "metrics_collected": {
      "mem": {
        "measurement": [
          {
            "name": "mem_used_percent",
            "rename": "MemoryUsage",
            "unit": "Percent"
          }
        ],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": [
          {
            "name": "used_percent",
            "rename": "DiskUsage",
            "unit": "Percent"
          }
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "*"
        ]
      }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/discourse/shared/standalone/log/rails/production.log",
            "log_group_name": "/aws/ec2/discourse/rails",
            "log_stream_name": "{instance_id}",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/user-data.log",
            "log_group_name": "/aws/ec2/discourse/user-data",
            "log_stream_name": "{instance_id}",
            "timezone": "UTC"
          }
        ]
      }
    }
  }
}
CWEOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -s \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/cloudwatch-config.json || true

# Create maintenance script
cat > /usr/local/bin/discourse-update <<'UPDATEEOF'
#!/bin/bash
set -e
cd /var/discourse
git pull
./launcher rebuild app
UPDATEEOF

chmod +x /usr/local/bin/discourse-update

# Final status
echo "========================================="
echo "Bootstrap Complete!"
echo "========================================="
echo "Domain: ${domain_name}"
echo "Deployment Mode: ${deployment_mode}"
%{ if deployment_mode == "simple" ~}
echo ""
echo "Discourse should be accessible at:"
echo "  http://${domain_name}"
echo ""
echo "Please complete the setup wizard in your browser."
%{ else ~}
echo ""
echo "Next steps for production deployment:"
echo "1. Verify database connectivity"
echo "2. Run: cd /var/discourse && ./launcher bootstrap app"
echo "3. Start: ./launcher start app"
%{ endif ~}
echo "========================================="
echo "Bootstrap script finished at $(date)"
echo "========================================="

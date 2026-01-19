# Install Discourse on a Cloud Server

> To install and self-host Discourse, follow the steps below. But if you'd rather skip the setup, maintenance, and server management, our official Discourse hosting takes care of everything for you.
>
> [Learn more about Discourse hosting](https://discourse.org/pricing)

> If you prefer to self-host but need help setting it up we have partners who can help.
> [Click here to explore self-hosting set-up options](https://discourse.org/partners).

**Set up Discourse in under 30 minutes** with zero knowledge of Rails or Linux shell. Works on any Docker-compatible cloud provider or local server.

## Contents

- [Quick Start](#quick-start)
- [Requirements](#requirements)
- [Installation](#installation)
- [The Setup Wizard](#the-setup-wizard)
- [After Installation](#after-installation)
- [Advanced Configuration](#advanced-configuration)
- [Troubleshooting](#troubleshooting)
- [Optional Features](#optional-features)

---

## Quick Start

Run this single command on a fresh Ubuntu/Debian server:

```bash
wget -qO- https://raw.githubusercontent.com/discourse/discourse_docker/main/install-discourse | sudo bash
```

That's it! The installer will:

- Install Docker and git automatically (if not present)
- Download the Discourse Docker configuration
- Launch an interactive setup wizard

> **Don't have a domain name?** No problem! The installer offers free subdomains like `yoursite.discourse.diy` — no purchase required.
>
> **Don't want to set up email?** Skip SMTP and users can log in via Discourse ID with social logins (Google, Facebook, Apple, GitHub).

---

## Requirements

### Server Specifications

| Requirement | Minimum | Recommended |
|-------------|---------|-------------|
| RAM | 1 GB (with swap) | 2 GB+ |
| CPU | 1 core | 2+ cores |
| Disk | 10 GB | 20 GB+ |
| OS | 64-bit Linux | Ubuntu 22.04+ LTS |

> **Auto-scaling:** The installer automatically tunes `UNICORN_WORKERS` and `db_shared_buffers` based on your server's RAM and CPU.

### Supported Cloud Providers

The installer works on any cloud provider with Docker support:

- [DigitalOcean](https://www.digitalocean.com/?refcode=5fa48ac82415)
- AWS EC2
- Google Cloud Platform
- Linode / Akamai
- Vultr
- Hetzner
- Any VPS with root SSH access

---

## Installation

### Step 1: Choose Your Domain

You have two options:

| Option | Best For | Setup |
|--------|----------|-------|
| **Free subdomain** (`mysite.discourse.diy`) | Testing, learning, hobby projects | Claim at [id.discourse.com/my/subdomain](https://id.discourse.com/my/subdomain) |
| **Your own domain** (`forum.example.com`) | Production, custom branding | Purchase from a registrar, configure DNS A record |

#### Free Subdomain

Visit [id.discourse.com/my/subdomain](https://id.discourse.com/my/subdomain) anytime to claim your subdomain. You can do this before or during installation:

1. Log in with your Discourse account (or create one)
2. Choose your desired subdomain name (e.g., `mysite`)
3. When ready to install, click **"Generate Code"** to get a 6-digit verification code (valid for 10 minutes)

> **How it works:** The installer verifies your code with Discourse ID, then automatically creates a DNS A record pointing `yoursite.discourse.diy` to your server's IP. No manual DNS configuration required!

#### Your Own Domain

1. Purchase a domain from a registrar like [Namecheap](https://www.namecheap.com/domains/domain-name-search/)
2. Create a DNS **A record** pointing your subdomain (e.g., `forum.example.com`) to your server's IP address
3. Wait for DNS propagation (can take up to 48 hours, usually much faster)

---

### Step 2: Create and Access Your Server

1. **Create a cloud server** on any provider (e.g., a DigitalOcean droplet with Ubuntu)

2. **SSH into your server:**
   ```bash
   ssh root@your-server-ip
   ```

---

### Step 3: Run the Installer

```bash
wget -qO- https://raw.githubusercontent.com/discourse/discourse_docker/main/install-discourse | sudo bash
```

The wizard will guide you through:

1. **Admin email(s)** — Enter the email addresses for admin accounts
2. **Domain selection:**
   - Select **No** for free subdomain → enter your subdomain and verification code
   - Select **Yes** for your own domain → enter your hostname (e.g., `forum.example.com`)
3. **SMTP configuration** — Skip to use Discourse ID login, or configure your email provider
4. **Let's Encrypt** — Confirm email for SSL certificate notifications
5. **MaxMind** (optional) — For IP geolocation features

After confirming your settings, the installer builds your Discourse (~5-10 minutes).

---

## The Setup Wizard

### SMTP is Optional

Unlike previous versions, **you can skip email configuration** during initial setup. When you skip SMTP, the installer automatically enables **Login via Discourse ID**, which provides:

- **Email-based login** — Users sign in through id.discourse.com (no SMTP needed)
- **Social logins** — Google, Facebook, Apple, and GitHub authentication built-in
- **Centralized identity** — Users can use the same account across multiple Discourse communities
- **Web push notifications** — Users still receive real-time notifications on all browsers and PWA-enabled devices

This is perfect for:

- Getting started quickly without email provider setup
- Communities that prefer social login over email registration
- Mobile-first communities using the PWA experience

> **Note:** If you want traditional email features (email digests, mailing list mode, or email replies), you can configure SMTP later via **Admin → Email** or by re-running the setup wizard.

### Automatic Features

The wizard handles these automatically:

- **Public IP detection** — Finds your server's IP using multiple services
- **Resource scaling** — Sets optimal `UNICORN_WORKERS` and `db_shared_buffers` based on your hardware
- **Port validation** — Checks that ports 80 and 443 are available
- **DNS verification** — Confirms your domain resolves to this server
- **Swap creation** — Offers to create swap space on low-memory servers

---

## After Installation

### Access Your Forum

Once the build completes (5-10 minutes), your forum will be available at:

- `https://yoursite.discourse.diy` (free subdomain)
- `https://forum.example.com` (your own domain)

### Register Your Admin Account

1. Visit your forum URL
2. Click **Sign Up** or **Log In**
3. If using Discourse ID login: sign in with Google, Facebook, Apple, GitHub, or email via id.discourse.com
4. If using SMTP: use one of the admin emails you entered during setup and check your inbox
5. Complete the in-app setup wizard that appears after registration

> **Tip:** Make sure you register with one of the admin emails you entered during installation to get admin privileges.

<img src="https://www.discourse.org/images/install/18/discourse-4-wizard-step1.png" width="650">

### Post-Install Security

We strongly recommend enabling automatic security updates:

```bash
# Ubuntu/Debian - enable unattended upgrades
dpkg-reconfigure -plow unattended-upgrades

# Install fail2ban for brute-force protection
apt install fail2ban
```

### Upgrading Discourse

**Via web UI (recommended):**
Visit `https://your-forum/admin/upgrade` and click **Upgrade**

**Via command line:**
```bash
cd /var/discourse
./launcher rebuild app
```

> Discourse will email you when new versions are available. Stay current for the latest features and security fixes.

---

## Advanced Configuration

### Manual Configuration

For advanced users, edit the configuration file directly:

```bash
nano /var/discourse/containers/app.yml
cd /var/discourse
./launcher rebuild app
```

### Launcher Commands

The `launcher` script in `/var/discourse` provides these commands:

```
Usage: launcher COMMAND CONFIG [--skip-prereqs] [--docker-args STRING]
Commands:
    start       Start/initialize a container
    stop        Stop a running container
    restart     Restart a container
    destroy     Stop and remove a container
    enter       Open a shell inside the container
    logs        View Docker logs for a container
    bootstrap   Bootstrap a container from template
    rebuild     Rebuild a container (destroy old, bootstrap, start new)
    cleanup     Remove stopped containers (> 24 hours old)
```

---

## Troubleshooting

### Ports 80/443 Already in Use

```bash
# Check what's using the ports
lsof -i :80
lsof -i :443

# Stop conflicting services
systemctl stop nginx    # or apache2
systemctl disable nginx
```

### DNS Verification Fails

- Ensure your A record points to the correct server IP
- DNS propagation can take up to 48 hours
- Use `--skip-connection-test` to bypass verification temporarily

### Free Subdomain Issues

- Ensure you're using the same Discourse ID account that claimed the subdomain
- Verification codes expire after **10 minutes** — generate a new one if expired
- Each subdomain can only be claimed by one user

### Build or Bootstrap Errors

```bash
# View container logs
cd /var/discourse
./launcher logs app

# Enter container for debugging
./launcher enter app

# Check Rails production logs
cat /var/discourse/shared/standalone/log/rails/production.log
```

### Low Memory Errors

The installer will offer to create swap space. You can also create it manually:

```bash
# Create 2GB swap
fallocate -l 2G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile swap swap defaults 0 0' >> /etc/fstab
```

### Email Not Working

If you configured SMTP but emails aren't sending, see the [Email Troubleshooting Guide](https://meta.discourse.org/t/troubleshooting-email-on-a-new-discourse-install/16326).

---

## Optional Features

After installation, you can enable additional features:

### Authentication

- [Google OAuth2](https://meta.discourse.org/t/configuring-google-oauth2-login-for-discourse/15858)
- [GitHub Login](https://meta.discourse.org/t/configuring-github-login-for-discourse/13745)
- [Facebook Login](https://meta.discourse.org/t/configuring-facebook-login-for-discourse/13394)
- [Twitter/X Login](https://meta.discourse.org/t/configuring-twitter-login-for-discourse/13395)
- [Single Sign-On (SSO)](https://meta.discourse.org/t/official-single-sign-on-for-discourse/13045)
- [More auth plugins on meta.discourse.org](https://meta.discourse.org/tags/c/plugin/22/auth-plugins)


### Email & Notifications

- [Reply via Email](https://meta.discourse.org/t/set-up-reply-via-email-support/14003)
- [Recommended Email Providers](https://github.com/discourse/discourse/blob/main/docs/INSTALL-email.md) — If you skipped SMTP during setup

### Operations

- [Automatic Backups](https://meta.discourse.org/t/configure-automatic-backups-for-discourse/14855)
- [Configure a CDN](https://meta.discourse.org/t/enable-a-cdn-for-your-discourse/14857)
- [Multisite Configuration](https://meta.discourse.org/t/multisite-configuration-with-docker/14084)
- [Webhooks](https://meta.discourse.org/t/setting-up-webhooks/49045)
- [Offline Page During Rebuild](https://meta.discourse.org/t/adding-an-offline-page-when-rebuilding/45238)

### Extending Discourse

- [Install Plugins](https://meta.discourse.org/t/install-a-plugin/19157)
- [Import from Other Platforms](https://meta.discourse.org/t/how-to-migrate-from-one-platform-forum-to-discourse/197236) — vBulletin, phpBB, Vanilla, etc.
- [Embed in WordPress](https://github.com/discourse/wp-discourse)
- [Embed Comments on Static Sites](https://meta.discourse.org/t/embedding-discourse-comments-via-javascript/31963)

---

Help us improve this guide! Feel free to ask questions on [meta.discourse.org](https://meta.discourse.org) or submit a pull request.

> Still finding setup too complex? [Let us host Discourse for you](https://discourse.org/pricing) — we handle everything.

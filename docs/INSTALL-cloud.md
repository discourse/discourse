**Set up Discourse in the cloud in under 30 minutes** with zero knowledge of Rails or Linux shell. One example
is [DigitalOcean][do], but these steps will work on any **Docker-compatible** cloud provider or local server. This
walkthrough will go through these in detail:

**[Before you start](#before-you-start)**

1. [Preparing your domain name](#1-preparing-your-domain-name)
2. [Setting up email](#2-setting-up-email)

**[Installation](#installation)**

3. [Create new cloud server](#3-create-new-cloud-server)
4. [Access new cloud server](#4-access-your-cloud-server)
5. [Install Prerequisites for Docker](#5-install-prerequisites-for-docker-debianubuntu-based-distro-example)
6. [Install Discourse](#6-install-discourse)
7. [Edit Discourse configuration](#7-edit-discourse-configuration)
8. [Start Discourse](#8-start-discourse)
9. [Register new account and become admin](#9-register-new-account-and-become-admin)
10. [Post-install maintenance](#10-post-install-maintenance)
11. [(Optional) Add more Discourse features](#11-optional-add-more-discourse-features)

> 🔔 Don't have 30 minutes to set this up? For a flat one-time fee of $150, the community can install Discourse in the cloud for you. [Click here to purchase a self-supported community install](https://www.literatecomputing.com/product/discourse-install/).

## Before you start

### 1. Preparing your domain name

> 🔔 Discourse will not work from an IP address, you must own a domain name such as `example.com` to proceed.

- Already own a domain name? Great. Select a subdomain such as `discourse.example.com` or `talk.example.com` or `forum.example.com` for your Discourse instance.

- No domain name? Get one! We can [recommend NameCheap](https://www.namecheap.com/domains/domain-name-search/), or there are many other [great domain name registrars](https://www.google.com/search?q=best+domain+name+registrars) to choose from.

- Your DNS controls should be accessible from the place where you purchased your domain name. This is where you will create a DNS [ `A` record](https://support.dnsimple.com/articles/a-record/) for the `discourse.example.com` hostname once you know the IP address of the cloud server where you are installing Discourse, as well as enter your [SPF and DKIM records](https://www.google.com/search?q=what+is+spf+dkim) for your email.

### 2. Setting Up Email

> ⚠️ **Email is CRITICAL for account creation and notifications in Discourse.** If you do not properly configure email before bootstrapping YOU WILL HAVE A BROKEN SITE!

> 💡 Email here refers to [Transactional Email](https://www.google.com/search?q=what+is+transactional+email) not the usual email service like Gmail, Outlook and/or Yahoo.

- No existing mail server? Check out our [**Recommended Email Providers for Discourse**][mailconfig].

- Already have a mail server? Great. Use your existing mail server credentials. (Free email services like Gmail/Outlook/Yahoo do not support transactional emails.)

- To ensure mail deliverability, you must add valid [SPF and DKIM records](https://www.google.com/search?q=what+is+spf+dkim) in your DNS. You'll need SMTP credentials from your email provider, which include an SMTP username and password. Log in to your email provider's account, go to SMTP settings or Email API section, and locate/generate your unique SMTP credentials. Keep them secure, as you'll use them during the Discourse configuration. See your mail provider instructions for specifics.

- When creating the DKIM record, some cloud hosting providers may append the domain name automatically to the input for public key. Do check that the created record has the expected public key value.

- If you're having trouble getting emails to work, follow our [Email Troubleshooting Guide](https://meta.discourse.org/t/troubleshooting-email-on-a-new-discourse-install/16326)

## Installation

### 3. Create New Cloud Server

Create your new cloud server, for example [on DigitalOcean][do]:

- The default of **the current supported LTS release of Ubuntu Server** works fine. At minimum, a 64-bit Linux OS with a
  modern kernel version is required.

- The default of **1 GB** RAM works fine for small Discourse communities. We recommend 2 GB RAM for larger communities.

- The default of **New York** is a good choice for most US and European audiences. Or select a region that is geographically closer to your audience.

- Enter your domain `discourse.example.com` as the Droplet name.

Create your new Droplet. You may receive an email with the root password, however, [you should set up SSH keys](https://www.google.com/search?q=digitalocean+ssh+keys), as they are more secure.

> ⚠️ Now you have created your cloud server! Go back to your DNS controls and use the IP address to set up an `A record` for your `discourse.example.com` hostname.

### 4. Access Your Cloud Server

Connect to your server via its IP address using SSH, or [Putty][put] on Windows:

    ssh root@192.168.1.1

Either use the root password from the email DigitalOcean sent you when the server was set up, or have a valid SSH key configured on your local machine.

### 5. Install Prerequisites for Docker (Debian/Ubuntu based Distro example)

    sudo apt install docker.io
    sudo apt install git

### 6. Install Discourse

Clone the [Official Discourse Docker Image][dd] into `/var/discourse`.

    sudo -s
    git clone https://github.com/discourse/discourse_docker.git /var/discourse
    cd /var/discourse
    chmod 700 containers

You will need to be root through the rest of the setup and bootstrap process.

### 7. Edit Discourse Configuration

Launch the setup tool at

    ./discourse-setup

Answer the following questions when prompted:

    Hostname for your Discourse? [discourse.example.com]: 
    Email address for admin account(s)? [me@example.com,you@example.com]: 
    SMTP server address? [smtp.example.com]: 
    SMTP port? [587]: 
    SMTP user name? [user@example.com]: 
    SMTP password? [pa$$word]: 
    Let's Encrypt account email? (ENTER to skip) [me@example.com]: 
    Optional Maxmind License key () [xxxxxxxxxxxxxxxx]:

You'll get the SMTP details from your [email](#2-setting-up-email) setup, be sure to complete that section.

Let's Encrypt account setup is to give you a free HTTPS certificate for your site, be sure to set that up if you want your site secure.

This will generate an `app.yml` configuration file on your behalf, and then kicks off bootstrap. Bootstrapping takes between **2-8 minutes** to set up your Discourse. If you need to change these settings after bootstrapping, you can run `./discourse-setup` again (it will re-use your previous values from the file) or edit `/containers/app.yml` manually with `nano` and then `./launcher rebuild app`, otherwise your changes will not take effect.

### 8. Start Discourse

 Once bootstrapping is complete, your Discourse should be accessible in your web browser via the domain name `discourse.example.com` you entered earlier.

<img src="https://www.discourse.org/images/install/18/discourse-1-congrats.png" width="650">

### 9. Register New Account and Become Admin

Register a new admin account using one of the email addresses you entered before bootstrapping.

<img src="https://www.discourse.org/images/install/18/discourse-2-register.png" width="650">

<img src="https://www.discourse.org/images/install/18/discourse-3-activate.png" width="650">

(If you are unable to register your admin account, check the logs at `/var/discourse/shared/standalone/log/rails/production.log` and see our [Email Troubleshooting checklist](https://meta.discourse.org/t/troubleshooting-email-on-a-new-discourse-install/16326).)

After registering your admin account, the setup wizard will launch and guide you through basic configuration of your Discourse.

<img src="https://www.discourse.org/images/install/18/discourse-4-wizard-step1.png" width="650">

After finishing the setup wizard, a popup will welcome you to your new site. It will also link you to the admin guide, which we strongly recommend you look at right away and refer to frequently. The guide provides a setup checklist, important guidance on how to successfully launch your community, and troubleshooting tips.

<img src="https://www.discourse.org/images/install/18/discourse-5-home.png" width="650">

### 10. Post-Install Maintenance

- We strongly suggest you turn on automatic security updates for your OS. In Ubuntu use the `dpkg-reconfigure -plow unattended-upgrades` command. In CentOS/RHEL, use the [`yum-cron`](https://www.redhat.com/sysadmin/using-yum-cron) package.
- If you are using a password and not a SSH key, be sure to enforce a strong root password. In Ubuntu use the `apt install libpam-cracklib` package. We also recommend `fail2ban` which blocks any IP addresses for 10 minutes that attempt more than 3 password retries.
  - **Ubuntu**: `apt install fail2ban`
  - **CentOS/RHEL**: `sudo dnf install fail2ban`
- If you need or want a default firewall, [turn on ufw](https://meta.discourse.org/t/configure-a-firewall-for-discourse/20584) for Ubuntu or use `firewalld` for CentOS/RHEL.

> 💡 Discourse will send you an email notification when new versions of Discourse are released. Please stay current to get the latest features and security fixes. 

To **upgrade Discourse to the latest version**, visit `https://discourse.example.com/admin/upgrade` in your browser and click the Upgrade button.

Alternatively, you can ssh into your server and rebuild using:

```
cd /var/discourse
./launcher rebuild app
```

The `launcher` command in the `/var/discourse` folder can be used for various kinds of maintenance:

``` text
Usage: launcher COMMAND CONFIG [--skip-prereqs] [--docker-args STRING]
Commands:
    start:      Start/initialize a container
    stop:       Stop a running container
    restart:    Restart a container
    destroy:    Stop and remove a container
    enter:      Use nsenter to get a shell into a container
    logs:       View the Docker logs for a container
    bootstrap:  Bootstrap a container for the config based on a template
    rebuild:    Rebuild a container (destroy old, bootstrap, start new)
    cleanup:    Remove all containers that have stopped for > 24 hours

Options:
    --skip-prereqs             Don't check launcher prerequisites
    --docker-args              Extra arguments to pass when running docker
```

### 11. (Optional) Add More Discourse Features

Do you want...

* Users to log in *only* via your pre-existing website's registration system? [Configure Single-Sign-On](https://meta.discourse.org/t/official-single-sign-on-for-discourse/13045).

- Users to log in via [Google](https://meta.discourse.org/t/configuring-google-oauth2-login-for-discourse/15858), [Twitter](https://meta.discourse.org/t/configuring-twitter-login-for-discourse/13395), [GitHub](https://meta.discourse.org/t/configuring-github-login-for-discourse/13745), or  [Facebook](https://meta.discourse.org/t/configuring-facebook-login-for-discourse/13394)?

- Users to post replies via email? [Configure reply via email](https://meta.discourse.org/t/set-up-reply-via-email-support/14003).

- Automatic daily backups? [Configure backups](https://meta.discourse.org/t/configure-automatic-backups-for-discourse/14855).
 
- HTTPS / SSL support?
  - Free HTTPS / SSL support with Let's Encrypt is enabled [during standard installation](https://github.com/discourse/discourse/blob/main/docs/INSTALL-cloud.md#6-edit-discourse-configuration).  If you skipped this step, [Configure Let's Encrypt](https://meta.discourse.org/t/setting-up-lets-encrypt-cert-with-discourse-docker/40709).
  - Paid HTTPS / SSL support? [Configure SSL](https://meta.discourse.org/t/allowing-ssl-for-your-discourse-docker-setup/13847). 

- Use a plugin [from Discourse](https://github.com/discourse) or a third party? [Configure plugins](https://meta.discourse.org/t/install-a-plugin/19157) 

- Multiple Discourse sites on the same server? [Configure multisite](https://meta.discourse.org/t/multisite-configuration-with-docker/14084).

- Webhooks when events happen in Discourse? [Configure webhooks](https://meta.discourse.org/t/setting-up-webhooks/49045).

- A Content Delivery Network to speed up worldwide access? [Configure a CDN](https://meta.discourse.org/t/enable-a-cdn-for-your-discourse/14857). We recommend [Fastly](http://www.fastly.com/).

- Import/migrate old content from vBulletin, PHPbb, Vanilla, Drupal, BBPress, etc? [See our open source importers](https://github.com/discourse/discourse/tree/main/script/import_scripts) and our [migration guide](https://meta.discourse.org/t/how-to-migrate-from-one-platform-forum-to-discourse/197236).

- A user friendly [offline page when rebuilding or upgrading?](https://meta.discourse.org/t/adding-an-offline-page-when-rebuilding/45238)

- To embed Discourse [in your WordPress install](https://github.com/discourse/wp-discourse), or [on your static HTML site](https://meta.discourse.org/t/embedding-discourse-comments-via-javascript/31963)?

Help us improve this guide! Feel free to ask about it on [meta.discourse.org][meta], or even better, submit a pull request.

   [dd]: https://github.com/discourse/discourse_docker
  [ssh]: https://help.github.com/articles/generating-ssh-keys
 [meta]: https://meta.discourse.org
   [do]: https://www.digitalocean.com/?refcode=5fa48ac82415
  [put]: http://www.chiark.greenend.org.uk/~sgtatham/putty/download.html
  [mailconfig]: https://github.com/discourse/discourse/blob/main/docs/INSTALL-email.md

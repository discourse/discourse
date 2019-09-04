**Set up Discourse in the cloud in under 30 minutes** with zero knowledge of Rails or Linux shell. One example is [DigitalOcean][do], but these steps will work on any **Docker-compatible** cloud provider or local server.

>  🔔 Don't have 30 minutes to set this up? For a flat one-time fee of $99, the community can install Discourse in the cloud for you. [Click here to purchase a self-supported community install](https://www.literatecomputing.com/product/discourse-install/).

### Create New Cloud Server

Create your new cloud server, for example [on DigitalOcean][do]:

- The default of **Ubuntu 18.04 LTS x64** works fine. At minimum, a 64-bit Linux OS with a kernel version of 3.10+ is required.

- The default of **1 GB** RAM works fine for small Discourse communities. We recommend 2 GB RAM for larger communities.

- The default of **New York** is a good choice for most US and European audiences. Or select a region that is geographically closer to your audience.

- Enter your domain `discourse.example.com` as the Droplet name.

Create your new Droplet. You will receive an email with the root password. (However, if you know [how to use SSH keys](https://www.google.com/search?q=digitalocean+ssh+keys), you may not need a password to log in.)

### Access Your Cloud Server

Connect to your server via its IP address using SSH, or [Putty][put] on Windows:

    ssh root@192.168.1.1

Enter the root password from the email DigitalOcean sent you when the server was set up. You will be prompted to change the root password.

<img src="https://www.discourse.org/images/install/15/ssh-login-terminal.png" width="600px">

### Install Docker / Git

    wget -qO- https://get.docker.com/ | sh

This command installs the latest versions of Docker and Git on your server. Alternately, you can manually [install Git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git) and the [Docker package for your OS](https://docs.docker.com/installation/).

### Install Discourse

Create a `/var/discourse` folder, clone the [Official Discourse Docker Image][dd] into it:

    sudo -s
    git clone https://github.com/discourse/discourse_docker.git /var/discourse
    cd /var/discourse

You will need to be root through the rest of the setup and bootstrap process.

### Email

> ⚠️ **Email is CRITICAL for account creation and notifications in Discourse.** If you do not properly configure email before bootstrapping YOU WILL HAVE A BROKEN SITE!

- Already have a mail server? Great. Use your existing mail server credentials.

- No existing mail server? Check out our [**Recommended Email Providers for Discourse**][mailconfig].

- To ensure mail deliverability, you must add valid [SPF and DKIM records](https://www.google.com/search?q=spf+dkim) in your DNS. See your mail provider instructions for specifics.

### Domain Name

> 🔔 Discourse will not work from an IP address, you must own a domain name such as `example.com` to proceed.

- Already own a domain name? Great. Select a subdomain such as `discourse.example.com` or `talk.example.com` or `forum.example.com` for your Discourse instance.

- No domain name? We can [recommend NameCheap](https://www.namecheap.com/domains/domain-name-search/), or there are many other [great domain name registrars](https://www.google.com/search?q=best+domain+name+registrars) to choose from.

- Your DNS controls should be accessible from the place where you purchased your domain name. Create a DNS A record for the `discourse.example.com` subdomain in your DNS control panel, pointing to the IP address of your cloud instance where you are installing Discourse.

### Edit Discourse Configuration

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

This will generate an `app.yml` configuration file on your behalf, and then kicks off bootstrap. Bootstrapping takes between **2-8 minutes** to set up your Discourse. If you need to change these settings after bootstrapping, you can run `./discourse-setup` again (it will re-use your previous values from the file) or edit `/containers/app.yml` manually with `nano` and then `./launcher rebuild app`, otherwise your changes will not take effect.

### Start Discourse

 Once bootstrapping is complete, your Discourse should be accessible in your web browser via the domain name `discourse.example.com` you entered earlier.

<img src="https://www.discourse.org/images/install/17/discourse-congrats.png" width="650">

### Register New Account and Become Admin

Register a new admin account using one of the email addresses you entered before bootstrapping.

<img src="https://www.discourse.org/images/install/17/discourse-register.png" width="650">

<img src="https://www.discourse.org/images/install/17/discourse-activate.png" width="650">

(If you are unable to register your admin account, check the logs at `/var/discourse/shared/standalone/log/rails/production.log` and see our [Email Troubleshooting checklist](https://meta.discourse.org/t/troubleshooting-email-on-a-new-discourse-install/16326).)

After registering your admin account, the setup wizard will launch and guide you through basic configuration of your Discourse.

<img src="https://www.discourse.org/images/install/17/discourse-wizard-step-1.png" width="650">

After completing the setup wizard, you should see Staff topics and **READ ME FIRST: Admin Quick Start Guide**. This guide contains advice for further configuring and customizing your Discourse install.

<img src="https://www.discourse.org/images/install/17/discourse-homepage.png">

### Post-Install Maintenance

- We strongly suggest you turn on automatic security updates for your OS. In Ubuntu use the `dpkg-reconfigure -plow unattended-upgrades` command. In CentOS/RHEL, use the [`yum-cron`](https://www.cyberciti.biz/faq/fedora-automatic-update-retrieval-installation-with-cron/) package.
- If you are using a password and not a SSH key, be sure to enforce a strong root password. In Ubuntu use the `apt-get install libpam-cracklib` package. We also recommend `fail2ban` which blocks any IP addresses for 10 minutes that attempt more than 3 password retries.
  - **Ubuntu**: `apt-get install fail2ban`
  - **CentOS/RHEL**: `sudo yum install fail2ban` (requires [EPEL](https://support.rackspace.com/how-to/install-epel-and-additional-repositories-on-centos-and-red-hat/))
- If you need or want a default firewall, [turn on ufw](https://meta.discourse.org/t/configure-a-firewall-for-discourse/20584) for Ubuntu or use `firewalld` for CentOS/RHEL 7 or later.

You will get email reminders as new versions of Discourse are released. Please stay current to get the latest features and security fixes. To **upgrade Discourse to the latest version**, visit `/admin/upgrade` in your browser and click the Upgrade button.

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

### Add More Discourse Features

Do you want...

* Users to log in *only* via your pre-existing website's registration system? [Configure Single-Sign-On](https://meta.discourse.org/t/official-single-sign-on-for-discourse/13045).

- Users to log in via [Google](https://meta.discourse.org/t/configuring-google-oauth2-login-for-discourse/15858), [Twitter](https://meta.discourse.org/t/configuring-twitter-login-for-discourse/13395), [GitHub](https://meta.discourse.org/t/configuring-github-login-for-discourse/13745), or  [Facebook](https://meta.discourse.org/t/configuring-facebook-login-for-discourse/13394)?

- Users to post replies via email? [Configure reply via email](https://meta.discourse.org/t/set-up-reply-via-email-support/14003).

- Automatic daily backups? [Configure backups](https://meta.discourse.org/t/configure-automatic-backups-for-discourse/14855).
 
- Free HTTPS / SSL support? [Configure Let's Encrypt](https://meta.discourse.org/t/setting-up-lets-encrypt-cert-with-discourse-docker/40709). Paid HTTPS / SSL support? [Configure SSL](https://meta.discourse.org/t/allowing-ssl-for-your-discourse-docker-setup/13847).

- Use a plugin [from Discourse](https://github.com/discourse) or a third party? [Configure plugins](https://meta.discourse.org/t/install-a-plugin/19157) 

- Multiple Discourse sites on the same server? [Configure multisite](https://meta.discourse.org/t/multisite-configuration-with-docker/14084).

- Webhooks when events happen in Discourse? [Configure webhooks](https://meta.discourse.org/t/setting-up-webhooks/49045).

- A Content Delivery Network to speed up worldwide access? [Configure a CDN](https://meta.discourse.org/t/enable-a-cdn-for-your-discourse/14857). We recommend [Fastly](http://www.fastly.com/).

- Import old content from vBulletin, PHPbb, Vanilla, Drupal, BBPress, etc? [See our open source importers](https://github.com/discourse/discourse/tree/master/script/import_scripts).

- A user friendly [offline page when rebuilding or upgrading?](https://meta.discourse.org/t/adding-an-offline-page-when-rebuilding/45238)

- To embed Discourse [in your WordPress install](https://github.com/discourse/wp-discourse), or [on your static HTML site](https://meta.discourse.org/t/embedding-discourse-comments-via-javascript/31963)?

Help us improve this guide! Feel free to ask about it on [meta.discourse.org][meta], or even better, submit a pull request.

   [dd]: https://github.com/discourse/discourse_docker
  [ssh]: https://help.github.com/articles/generating-ssh-keys
 [meta]: https://meta.discourse.org
   [do]: https://www.digitalocean.com/?refcode=5fa48ac82415
  [put]: http://www.chiark.greenend.org.uk/~sgtatham/putty/download.html
  [mailconfig]: https://github.com/discourse/discourse/blob/master/docs/INSTALL-email.md

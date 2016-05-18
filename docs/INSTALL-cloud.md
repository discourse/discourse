**Set up Discourse in the cloud in under 30 minutes** with zero knowledge of Rails or Linux shell using our [Discourse Docker image][dd]. We recommend [DigitalOcean][do], but these steps will work on any Docker-compatible cloud provider or local server.

### Create New Cloud Server

[Sign up for DigitalOcean][do], update billing info, then create your new cloud server.

- Enter your domain `discourse.example.com` as the name.

- The default of **1 GB** RAM works fine for small Discourse communities. We recommend 2 GB RAM for larger communities.

- The default of **Ubuntu 14.04 LTS x64** works fine. At minimum, a 64-bit Linux OS with a kernel version of 3.10+ is required.

- The default of **New York** is a good choice for most US and European audiences. Or select a region that is geographically closer to your audience.

Create your new Droplet. You will receive an email with the root password. (However, if you know [how to use SSH keys](https://www.google.com/search?q=digitalocean+ssh+keys), you may not need a password to log in.)

### Access Your Cloud Server

Connect to your server via its IP address using SSH, or [Putty][put] on Windows:

    ssh root@192.168.1.1

Enter the root password from the email DigitalOcean sent you when the server was set up. You may be prompted to change the root password, too.

<img src="https://www.discourse.org/images/install/15/ssh-login-terminal.png" width="600px">

### Install Docker / Git

    wget -qO- https://get.docker.com/ | sh

This command installs the latest versions of Docker and Git on your server. Alternately, you can manually [install Git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git) and the [Docker package for your OS](https://docs.docker.com/installation/).

### Install Discourse

Create a `/var/discourse` folder, clone the [Official Discourse Docker Image][dd] into it:

    sudo -s
    mkdir /var/discourse
    git clone https://github.com/discourse/discourse_docker.git /var/discourse
    cd /var/discourse

You will need to be root through the rest of the setup and bootstrap process.

### Edit Discourse Configuration

Launch the setup tool at

    ./discourse-setup

Answer the following questions when prompted:

    Hostname for your Discourse? [discourse.example.com]: 
    Email address for admin account? [me@example.com]: 
    SMTP server address? [smtp.example.com]: 
    SMTP user name? [postmaster@discourse.example.com]: 
    SMTP password? []: 

This will generate an `app.yml` configuration file on your behalf, and then kicks off bootstrap. Bootstrapping takes between **2-8 minutes** to set up your Discourse.

### Email Is Important

**Email is CRITICAL for account creation and notifications in Discourse. If you do not properly configure email before bootstrapping YOU WILL HAVE A BROKEN SITE!**

- Already have a mail server? Great. Use your existing mail server credentials.

- No existing mail server? Check out our [**Recommended Email Providers for Discourse**][mailconfig].

- For proper email deliverability, add valid SPF and DKIM records in your DNS. See your email provider instructions for specifics.

If you need to change or fix your email settings after bootstrapping, edit your `app.yml` file and `./launcher rebuild app`, otherwise your changes will not take effect.

### Start Discourse

 Once bootstrapping is complete, your Discourse should be accessible in your web browser via the domain name `discourse.example.com` you entered earlier, provided you configured DNS. If not, you can visit the server IP directly, e.g. `http://192.168.1.1`.

<img src="https://www.discourse.org/images/install/15/browser-discourse-installed.png">

### Register New Account and Become Admin

Register a new admin account using one of the email addresses you entered before bootstrapping.

If you are unable to register your admin account, check the logs at `/var/discourse/shared/standalone/log/rails/production.log` and see our [Email Troubleshooting checklist](https://meta.discourse.org/t/troubleshooting-email-on-a-new-discourse-install/16326).

<img src="https://www.discourse.org/images/install/14/browser-logged-in-first-admin.png?v=1">

You should see Staff topics and **READ ME FIRST: Admin Quick Start Guide**. This guide contains the next steps for further configuring and customizing your Discourse install as an administrator. Read it closely!

(If you are still unable to register a new admin account via email, see [Create Admin Account from Console](https://meta.discourse.org/t/create-admin-account-from-console/17274), but note that *you will have a broken site* unless you get email working.)

### Post-Install Maintenance

We strongly suggest you:

- Turn on automatic security updates for your OS. In Ubuntu use the `dpkg-reconfigure -plow unattended-upgrades` command.
- If you are using a password and not a SSH key, be sure to enforce a strong root password. In Ubuntu use the `apt-get install libpam-cracklib` package.

You will get email reminders as new versions of Discourse are released. Please stay current to get the latest features and security fixes. To **upgrade Discourse to the latest version**, visit `/admin/upgrade` in your browser and click the Upgrade button.

The `launcher` command in the `/var/discourse` folder can be used for various kinds of maintenance:

```
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

- Multiple Discourse sites on the same server? [Configure multisite](https://meta.discourse.org/t/multisite-configuration-with-docker/14084).

- A Content Delivery Network to speed up worldwide access? [Configure a CDN](https://meta.discourse.org/t/enable-a-cdn-for-your-discourse/14857). We recommend [Fastly](http://www.fastly.com/).

- Import old content from vBulletin, PHPbb, Vanilla, Drupal, BBPress, etc? [See our open source importers](https://github.com/discourse/discourse/tree/master/script/import_scripts).

- A firewall on your server? [Configure firewall](https://meta.discourse.org/t/configure-a-firewall-for-discourse/20584).

- To embed Discourse [in your WordPress install](https://github.com/discourse/wp-discourse), or [on your static HTML site](https://meta.discourse.org/t/embedding-discourse-comments-via-javascript/31963)?

Help us improve this guide! Feel free to ask about it on [meta.discourse.org][meta], or even better, submit a pull request.

   [dd]: https://github.com/discourse/discourse_docker
  [ssh]: https://help.github.com/articles/generating-ssh-keys
 [meta]: https://meta.discourse.org
   [do]: https://www.digitalocean.com/?refcode=5fa48ac82415
  [put]: http://www.chiark.greenend.org.uk/~sgtatham/putty/download.html
  [mailconfig]: https://github.com/discourse/discourse/blob/master/docs/INSTALL-email.md

**Set up Discourse in the cloud in under 30 minutes** with zero knowledge of Rails or Linux shell using our [Discourse Docker image][dd]. We recommend [Digital Ocean][do], but these steps will work on any Docker-compatible cloud provider or local server.

# Create New Cloud Server

[Sign up for Digital Ocean][do], update billing info, then create your new cloud server.

- Enter your domain `discourse.example.com` as the name.

- The default of **1 GB** RAM works fine for small Discourse communities. We recommend 2 GB RAM for larger communities.

- The default of **Ubuntu 14.04 LTS x64** works fine. At minimum, a 64-bit Linux OS with a kernel version of 3.10+ is required.

- The default of **New York** is a good choice for most US and European audiences. Or select a region that is geographically closer to your audience.

Create your new Droplet. You will receive an email with the root password to your Droplet. (However, if you know [how to use SSH keys](https://www.google.com/search?q=digitalocean+ssh+keys), you may not need a password to log in.)

# Access Your Cloud Server

Connect to your server via SSH, or use [Putty][put] on Windows:

    ssh root@192.168.1.1

Replace `192.168.1.1` with the IP address of your server.

You will be asked for permission to connect, type `yes`, then enter the root password from the email Digital Ocean sent you when the server was set up. You may be prompted to change the root password, too.

<img src="https://www.discourse.org/images/install/14/console-ssh.png?v=1" width="600px">

# Set up Swap (if needed)

- If you're using the minimum 1 GB install, you *must* [set up a swap file](https://meta.discourse.org/t/create-a-swapfile-for-your-linux-server/13880).
- If you're using 2 GB+ memory, you can probably get by without a swap file.

# Install Docker / Git

    wget -qO- https://get.docker.com/ | sh

This command installs the latest versions of Docker and Git on your server. Alternately, you can manually install the respective [Docker package for your OS](https://docs.docker.com/installation/).

# Install Discourse

Create a `/var/discourse` folder, clone the [Official Discourse Docker Image][dd] into it, and make a copy of the config file as `app.yml`:

    mkdir /var/discourse
    git clone https://github.com/discourse/discourse_docker.git /var/discourse
    cd /var/discourse
    cp samples/standalone.yml containers/app.yml

# Edit Discourse Configuration

Edit the Discourse config file `app.yml`:

    nano containers/app.yml

We recommend Nano because it's simple; just use your arrow keys to edit.

- Set `DISCOURSE_DEVELOPER_EMAILS` to your email address.

- Set `DISCOURSE_HOSTNAME` to `discourse.example.com`, this means you want your Discourse available at `http://discourse.example.com/`. You'll need to update the DNS A record for this domain with the IP address of your server.

- Place your mail credentials in `DISCOURSE_SMTP_ADDRESS`, `DISCOURSE_SMTP_PORT`, `DISCOURSE_SMTP_USER_NAME`, `DISCOURSE_SMTP_PASSWORD`. Be sure you remove the comment `#` character and space from the front of these lines as necessary.

- If you are using a 1 GB instance, set `UNICORN_WORKERS` to 2 and `db_shared_buffers` to 128MB so you have more memory room.

<img src="https://www.discourse.org/images/install/14/console-nano-app-yml.png?v=1" width="600px">

After completing your edits, press <kbd>Ctrl</kbd><kbd>O</kbd> then <kbd>Enter</kbd> to save and <kbd>Ctrl</kbd><kbd>X</kbd> to exit.

# Email Is Important

**Email is CRITICAL for account creation and notifications in Discourse. If you do not properly configure email before bootstrapping YOU WILL HAVE A BROKEN SITE!**

- Already have a mail server? Great. Use your existing mail server credentials.

- No existing mail server? Create a free account on [SparkPost][sp] (10k emails/month) [Mailgun][gun] (10k emails/month), [Mailjet][jet] (200 emails/day) or [**Mandrill**][man], and use the credentials provided in the dashboard.

- For proper email deliverability, you must set the [SPF and DKIM records](http://help.mandrill.com/entries/21751322-What-are-SPF-and-DKIM-and-do-I-need-to-set-them-up-) in your DNS. In Mandrill, that's under Sending Domains, View DKIM/SPF setup instructions.

# Bootstrap Discourse

Save the `app.yml` file, and begin bootstrapping Discourse:

    ./launcher bootstrap app

This command takes about **8 minutes** to automagically configure your Discourse. After that completes, start Discourse:

    ./launcher start app

<img src="https://www.discourse.org/images/install/14/console-launcher-start.png?v=1" width="600px">

Congratulations! You just built your very own Discourse!

Your Discourse should be accessible in your web browser via the domain name `discourse.example.com` you entered earlier, provided you configured DNS. If not, you can visit the server IP directly, e.g. `http://192.168.1.1`.

<img src="https://www.discourse.org/images/install/14/browser-discourse-installed.png">

# Register New Account and Become Admin

There is a reminder at the top about the `DISCOURSE_DEVELOPER_EMAILS` you entered previously in `app.yml`; register a new account using one of those email addresses, and your account will automatically be made an Admin.

(If you *don't* get any email from your install, and are unable to register a new admin account, please see our [Email Troubleshooting checklist](https://meta.discourse.org/t/troubleshooting-email-on-a-new-discourse-install/16326).)

<img src="https://www.discourse.org/images/install/14/browser-logged-in-first-admin.png?v=1">

You should see Staff topics and **READ ME FIRST: Admin Quick Start Guide**. This guide contains the next steps for further configuring and customizing your Discourse install as an administrator. Read it closely!

(If you are still unable to register a new admin account via email, see [Create Admin Account from Console](https://meta.discourse.org/t/create-admin-account-from-console/17274), but please note that *you will have a broken site* unless you get email working on your instance.)

# Post-Install Maintenance

We strongly suggest you:

- Turn on automatic security updates for your OS. In Ubuntu use the `dpkg-reconfigure -plow unattended-upgrades` command.
- If you are using a password and not a SSH key, be sure to enforce a strong root password. In Ubuntu use the `apt-get install libpam-cracklib` package.

You will get email reminders as new versions of Discourse are released. Please stay current to get the latest features and security fixes. To **upgrade Discourse to the latest version**, visit `/admin/upgrade` in your browser and click the Upgrade button.

The `launcher` command in the `/var/discourse` folder can be used for various kinds of maintenance:

```
Usage: launcher COMMAND CONFIG [--skip-prereqs]
Commands:
    start:      Start/initialize a container
    stop:       Stop a running container
    restart:    Restart a container
    destroy:    Stop and remove a container
    enter:      Use nsenter to enter a container
    ssh:        Start a bash shell in a running container
    logs:       Docker logs for container
    bootstrap:  Bootstrap a container for the config based on a template
    rebuild:    Rebuild a container (destroy old, bootstrap, start new)
    cleanup:    Remove all containers that have stopped for > 24 hours

Options:
    --skip-prereqs   Don't check prerequisites
    --docker-args    Extra arguments to pass when running docker
```

# Add More Discourse Features

Do you want...

* Users to log in *only* via your pre-existing website's registration system? [Configure Single-Sign-On](https://meta.discourse.org/t/official-single-sign-on-for-discourse/13045).

- Users to log in via Google? (new Oauth2 authentication) [Configure Google logins](https://meta.discourse.org/t/configuring-google-oauth2-login-for-discourse/15858).

- Users to log in via Facebook? [Configure Facebook logins](https://meta.discourse.org/t/configuring-facebook-login-for-discourse/13394).

- Users to log in via Twitter? [Configure Twitter logins](https://meta.discourse.org/t/configuring-twitter-login-for-discourse/13395).

- Users to log in via GitHub? [Configure GitHub logins](https://meta.discourse.org/t/configuring-github-login-for-discourse/13745)

- Users to post replies via email? [Configure reply via email](https://meta.discourse.org/t/set-up-reply-via-email-support/14003).

- Automatic daily backups? [Configure backups](https://meta.discourse.org/t/configure-automatic-backups-for-discourse/14855).

- HTTPS / SSL support? [Configure SSL](https://meta.discourse.org/t/allowing-ssl-for-your-discourse-docker-setup/13847).

- Multiple Discourse sites on the same server? [Configure multisite](https://meta.discourse.org/t/multisite-configuration-with-docker/14084).

- A Content Delivery Network to speed up worldwide access? [Configure a CDN](https://meta.discourse.org/t/enable-a-cdn-for-your-discourse/14857). We recommend [Fastly](http://www.fastly.com/).

- Import old content from vBulletin, PHPbb, Vanilla, Drupal, BBPress, etc? [See our open source importers](https://github.com/discourse/discourse/tree/master/script/import_scripts)

- A firewall on your server? [Configure firewall](https://meta.discourse.org/t/configure-a-firewall-for-discourse/20584)

- To embed Discourse [in your WordPress install](https://github.com/discourse/wp-discourse), or [on your static HTML site](https://meta.discourse.org/t/embedding-discourse-comments-via-javascript/31963)?

Help us improve this guide! Feel free to ask about it on [meta.discourse.org][meta], or even better, submit a pull request.

   [dd]: https://github.com/discourse/discourse_docker
  [man]: https://mandrillapp.com
   [sp]: https://www.sparkpost.com/
  [ssh]: https://help.github.com/articles/generating-ssh-keys
 [meta]: https://meta.discourse.org
   [do]: https://www.digitalocean.com/?refcode=5fa48ac82415
  [jet]: https://www.mailjet.com/pricing
  [gun]: http://www.mailgun.com/
  [put]: http://www.chiark.greenend.org.uk/~sgtatham/putty/download.html

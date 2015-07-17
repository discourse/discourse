**Set up Discourse in the cloud in under 30 minutes** with zero knowledge of Rails or Linux shell using our [Discourse Docker image][dd]. We recommend [Digital Ocean][do], but these steps will work on any Docker-compatible cloud provider or local server.

# Create New Cloud Server

[Sign up for Digital Ocean][do], update billing info, then create your new cloud server (Droplet).

- Enter your domain `discourse.example.com` as the name.

- The default of **1 GB** RAM works fine for small Discourse communities. We do recommend 2 GB RAM for medium communities.

- The default of **Ubuntu 14.04 LTS x64** works fine. At minimum, a 64-bit Linux OS with a kernel version of 3.10+ is required.

- The default of **New York** is a good choice for most US and European audiences. Or select a region that is geographically closer to your audience.

Create your new Droplet. You will receive a mail from Digital Ocean with the root password to your Droplet. (However, if you know [how to use SSH keys](https://www.google.com/search?q=digitalocean+ssh+keys), you may not need a password to log in.)

# Access Your Cloud Server

Connect to your Droplet via SSH, or use [Putty][put] on Windows:

    ssh root@192.168.1.1

Replace `192.168.1.1` with the IP address of your Droplet.

<img src="http://www.discourse.org/images/install/ssh-login-start-1-3-beta.png?v=1">

You will be asked for permission to connect, type `yes`, then enter the root password from the email Digital Ocean sent you when the Droplet was set up. You may be prompted to change the root password, too.

<img src="http://www.discourse.org/images/install/ssh-login-1-3-beta.png?v=1">

# Set up Swap (if needed)

- If you're using the minimum 1 GB install, you *must* [set up a swap file](https://meta.discourse.org/t/create-a-swapfile-for-your-linux-server/13880).

- If you're using 2 GB+ memory, you can probably get by without a swap file.

# Install Docker / Git

    wget -qO- https://get.docker.com/ | sh

<img src="http://www.discourse.org/images/install/install-git-1-3-beta.png?v=1">

# Install Discourse

Create a `/var/discourse` folder, clone the [Official Discourse Docker Image][dd] into it, and make a copy of the config file as `app.yml`:

    mkdir /var/discourse
    git clone https://github.com/discourse/discourse_docker.git /var/discourse
    cd /var/discourse
    cp samples/standalone.yml containers/app.yml

<img src="http://www.discourse.org/images/install/mkdir-var-docker-1-3-beta.png?v=1">

# Edit Discourse Configuration

Edit the Discourse configuration at `app.yml`:

    nano containers/app.yml

We recommend Nano because it works like a typical GUI text editor, just use your arrow keys.

- Set `DISCOURSE_DEVELOPER_EMAILS` to your email address.

- Set `DISCOURSE_HOSTNAME` to `discourse.example.com`, this means you want your Discourse available at `http://discourse.example.com/`. You'll need to update the DNS A record for this domain with the IP address of your server.

- Place your mail credentials in `DISCOURSE_SMTP_ADDRESS`, `DISCOURSE_SMTP_PORT`, `DISCOURSE_SMTP_USER_NAME`, `DISCOURSE_SMTP_PASSWORD`. Be sure you remove the comment `#` character and space from the front of these lines as necessary.

- If you are using a 1 GB instance, set `UNICORN_WORKERS` to 2 and `db_shared_buffers` to 128MB so you have more memory room.

<img src="http://www.discourse.org/images/install/nano-screenshot-1-3-beta.png?v=1">

After completing your edits, press <kbd>Ctrl</kbd><kbd>O</kbd> then <kbd>Enter</kbd> to save and <kbd>Ctrl</kbd><kbd>X</kbd> to exit.

# Email Is Important

**Email is CRITICAL for account creation and notifications in Discourse. If you do not properly configure email before bootstrapping YOU WILL HAVE A BROKEN SITE!**

- Already have a mail server? Great. Use your existing mail server credentials.

- No existing mail server, or you don't know what it is? No problem, create a free account on [**Mandrill**][man] (or [Mailgun][gun], or [Mailjet][jet]), and use the credentials provided in the dashboard.

- For proper email deliverability, you must set the [SPF and DKIM records](http://help.mandrill.com/entries/21751322-What-are-SPF-and-DKIM-and-do-I-need-to-set-them-up-) in your DNS. In Mandrill, that's under Sending Domains, View DKIM/SPF setup instructions.

# Bootstrap Discourse

Save the `app.yml` file, and begin bootstrapping Discourse:

    ./launcher bootstrap app

This command takes about 8 minutes. It is automagically configuring your Discourse environment.

After that completes, start Discourse:

    ./launcher start app

<img src="http://www.discourse.org/images/install/launcher-start-app-1-3-beta.png?v=1">

Congratulations! You now have your own instance of Discourse!

It should be accessible via the domain name `discourse.example.com` you entered earlier, provided you configured DNS. If not, you can also visit the server IP directly, e.g. `http://192.168.1.1`.

<img src="http://www.discourse.org/images/install/congratulations-on-installing-discourse-1-3-beta.png?v=1">

# Register New Account and Become Admin

There is a reminder at the top about `DISCOURSE_DEVELOPER_EMAILS`; register a new account via one of those email addresses, and your account will automatically be made an Admin.

(If you *don't* get any email from your install, and are unable to register a new admin account, please see our [Email Troubleshooting checklist](https://meta.discourse.org/t/troubleshooting-email-on-a-new-discourse-install/16326).)

<img src="http://www.discourse.org/images/install/discourse-installed-1-3-beta.png?v=1">

You should see Staff topics and the [Admin Quick Start Guide](https://github.com/discourse/discourse/blob/master/docs/ADMIN-QUICK-START-GUIDE.md). It contains the next steps for further configuring and customizing your Discourse install.

(If you are still unable to register a new admin account via email, see [Create Admin Account from Console](https://meta.discourse.org/t/create-admin-account-from-console/17274), but please note that *you will have a broken site* unless you get email working on your instance.)


# Post-Install Maintenance

We strongly suggest you:

- turn on automatic security updates via the `dpkg-reconfigure -plow unattended-upgrades` command
- enable stronger passwords via the `apt-get install libpam-cracklib` package

To **upgrade Discourse to the latest version**, visit `/admin/upgrade` and follow the instructions.

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

- Users to log in via Google? (new Oauth2 authentication) [Configure Google logins](https://meta.discourse.org/t/configuring-google-login-for-discourse/15858).

- Users to log in via Facebook? [Configure Facebook logins](https://meta.discourse.org/t/configuring-facebook-login-for-discourse/13394).

- Users to log in via Twitter? [Configure Twitter logins](https://meta.discourse.org/t/configuring-twitter-login-for-discourse/13395/last).

- Users to post replies via email? [Configure reply via email](https://meta.discourse.org/t/set-up-reply-via-email-support/14003).

- Automatic daily backups? [Configure backups](https://meta.discourse.org/t/configure-automatic-backups-for-discourse/14855).

- HTTPS / SSL support? [Configure SSL](https://meta.discourse.org/t/allowing-ssl-for-your-discourse-docker-setup/13847).

- Multiple Discourse sites on the same server? [Configure multisite](https://meta.discourse.org/t/multisite-configuration-with-docker/14084).

- A Content Delivery Network to speed up worldwide access? [Configure a CDN](https://meta.discourse.org/t/enable-a-cdn-for-your-discourse/14857). We recommend [Fastly](http://www.fastly.com/).

- Import old content from vBulletin, PHPbb, Vanilla, Drupal, BBPress, etc? [See our open source importers](https://github.com/discourse/discourse/tree/master/script/import_scripts)

- A firewall on your server? [Configure firewall](https://meta.discourse.org/t/configure-a-firewall-for-discourse/20584)

- To embed Discourse [in your WordPress install](https://github.com/discourse/wp-discourse), or [on your static HTML site](http://eviltrout.com/2014/01/22/embedding-discourse.html)?

If anything needs to be improved in this guide, feel free to ask on [meta.discourse.org][meta], or even better, submit a pull request.

   [dd]: https://github.com/discourse/discourse_docker
  [man]: https://mandrillapp.com
  [ssh]: https://help.github.com/articles/generating-ssh-keys
 [meta]: https://meta.discourse.org
   [do]: https://www.digitalocean.com/?refcode=5fa48ac82415
  [jet]: https://www.mailjet.com/pricing
  [gun]: http://www.mailgun.com/
  [put]: http://www.chiark.greenend.org.uk/~sgtatham/putty/download.html

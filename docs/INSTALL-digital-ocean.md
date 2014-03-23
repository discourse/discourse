The [Discourse Docker Image][dd] makes it easy to set up Discourse on a cloud server. We will use [Digital Ocean][do], although these steps will work on other similar services.

This guide assumes that you have no knowledge of Ruby/Rails or Linux shell. Feel free to skip steps you are comfortable with.

# Create New Digital Ocean Droplet

Discourse requires a minimum of 1 GB RAM, however **2 GB RAM is strongly recommended**. We'll use "discourse" as the Hostname.

<img src="https://meta-discourse.r.worldssl.net/uploads/default/3506/a6b550bd2b05b76b.png" width="638" height="500"> 

Install Discourse on Ubuntu 12.04.3 LTS x64. We always recommend using [the current LTS distribution][lts].

<img src="https://meta-discourse.r.worldssl.net/uploads/default/3399/f3fc67ee6aa90ea4.png" width="690" height="477"> 

You will receive a mail from Digital Ocean with the root password to your Droplet. (However, if you use SSH keys, you may not need a password to log in.)

# Access Your Droplet

Connect to your Droplet via SSH:

    ssh root@192.168.1.1

(Alternately, use [Putty][put] on Windows)

Replace `192.168.1.1` with the IP address of your Droplet.

<img src="https://meta-discourse.r.worldssl.net/uploads/default/2999/0934a0158459ec3f.png" width="571" height="130"> 

You will be asked for permission to connect, type `yes`, then the root password, which is in the email Digital Ocean sent you when the Droplet was set up. Enter it.

<img src="https://meta-discourse.r.worldssl.net/uploads/default/3000/8209c1e40c9d70a8.png" width="570" height="278"> 

# Install Git

    apt-get install git

<img src="https://meta-discourse.r.worldssl.net/uploads/default/3002/eafbf14df8eee832.png" width="572" height="263"> 

# Install Docker

Update to a newer kernel:

    apt-get update
    apt-get install linux-image-generic-lts-raring linux-headers-generic-lts-raring

<img src="https://meta-discourse.r.worldssl.net/uploads/default/3001/e94722e882f28994.png" width="566" height="339"> 

Reboot the server:

    reboot

<img src="https://meta-discourse.r.worldssl.net/uploads/default/3003/d3cc759ced335d25.png" width="532" height="155"> 

This will log you out from your SSH session, so reconnect:

    ssh root@192.168.1.1

Finish installing Docker:

    wget -qO- https://get.docker.io/ | sh

# Install Discourse

Create a `/var/docker` folder where all the Docker related stuff will reside:

    mkdir /var/docker

Clone the [Official Discourse Docker Image][dd] into this `/var/docker` folder:

    git clone https://github.com/discourse/discourse_docker.git /var/docker

Switch to your Docker folder:

    cd /var/docker

Copy the `samples/standalone.yml` file into the `containers` folder as `app.yml`, so the path becomes `containers/app.yml`:

    cp samples/standalone.yml containers/app.yml

<img src="https://meta-discourse.r.worldssl.net/uploads/default/3005/5c253f4657e2133f.png" width="571" height="56"> 

Edit `app.yml`:

    nano containers/app.yml

(We recommend Nano because it works like a typical GUI text editor, just use your arrow keys. Hit <kbd>Ctrl</kbd><kbd>O</kbd> then <kbd>Enter</kbd> to save and <kbd>Ctrl</kbd><kbd>X</kbd> to exit. However, feel free to choose whatever text editor you like. In the below screenshot we use Vim.)

<img src="https://meta-discourse.r.worldssl.net/uploads/default/3006/ed9f51b3a44f2b86.png" width="572" height="451"> 

Edit as desired, but at minimum set `DISCOURSE_DEVELOPER_EMAILS` and `DISCOURSE_HOSTNAME`.

<img src="https://meta-discourse.r.worldssl.net/uploads/default/2979/e6fedbde9b471880.png" width="565" height="172"> 

If you set `DISCOURSE_HOSTNAME` to `discourse.example.com`, this means you want to host our instance of Discourse on `http://discourse.example.com/`. You'll need to change your DNS records to reflect the IP address and preferred URL address of your server.

# Mail Setup

**Email is critical to Discourse. We strongly recommend configuring mail settings before bootstrapping.**

- If you already have a mail server, put your existing mail server credentials in the `app.yml` file.

- Otherwise, create a free account on [**Mandrill**][man] (or [Mailgun][gun], or [Mailjet][jet]), and put your mail credentials (available via the Mandrill dashboard) in the `app.yml` file. The settings you want to change are `DISCOURSE_SMTP_ADDRESS`, `DISCOURSE_SMTP_PORT`, `DISCOURSE_SMTP_USER_NAME`, `DISCOURSE_SMTP_PASSWORD`.

- Be sure you remove the comment character and space `# ` from the beginning of these mail configuration lines!

- Don't forget to set the [SPF and DKIM records](http://help.mandrill.com/entries/21751322-What-are-SPF-and-DKIM-and-do-I-need-to-set-them-up-) up for your domain name. In Mandrill, that's under Sending Domains, View DKIM/SPF setup instructions.

- The name of your droplet is your reverse PTR record, so rename your droplet to `discourse.example.com` so the PTR record correctly reflects your domain name.

# Bootstrap Discourse

Be sure to save the `app.yml` file, and begin bootstrapping Discourse:

    ./launcher bootstrap app

<img src="https://meta-discourse.r.worldssl.net/uploads/default/3007/c0596ad3d330ae71.png" width="567" height="138"> 

This command may take some time, so be prepared to wait. It is automagically configuring your Discourse environment.

After that completes, start Discourse:

    ./launcher start app

<img src="https://meta-discourse.r.worldssl.net/uploads/default/3008/ced00cf4782f020c.png" width="568" height="137"> 

Congratulations! You now have your own instance of Discourse, accessible via the domain name you entered in `app.yml` earlier.

<img src="https://meta-discourse.r.worldssl.net/uploads/default/3507/d01eee7415f860f2.png" width="690" height="291">

You can also access it by visiting the server IP address directly, e.g. `http://192.168.1.1`.

# Log In and Become Admin

Sign into your Discourse instance. There should be a reminder visible on the site about which email was used for the  `DISCOURSE_DEVELOPER_EMAILS` address. Be sure you log in with that email, and your account will be made Admin by default.

# Post-Install Maintenance

We believe most small and medium size Discourse installs will be fine with the recommended 2 GB of RAM. However, if you are using the absolute minimum 1 GB of RAM, or your forum is growing you may want to [set up a swap file](https://meta.discourse.org/t/create-a-swapfile-for-your-linux-server/13880) just in case.

To **upgrade Discourse to the latest version**, visit `/admin/docker`, refresh the page a few times (yes, seriously) and then press the Upgrade button at the top. View the live output at the bottom of your browser to see when things are complete. You should see:


    Killed sidekiq
    Restarting unicorn pid: 37


Then you know it's complete. (Yes, we will be improving this process soon!)

# Other Optional Stuff

Do you want...

- Users to log in via Facebook? [Configure Facebook logins](https://meta.discourse.org/t/configuring-facebook-login-for-discourse/13394).

- Users to log in via Twitter? [Configure Twitter logins](https://meta.discourse.org/t/configuring-twitter-login-for-discourse/13395/last).

- Users to post reples via email? [Configure reply via email](https://meta.discourse.org/t/set-up-reply-via-email-support/14003).

If anything needs to be improved in this guide, feel free to ask on [meta.discourse.org][meta], or even better, submit a pull request.

   [dd]: https://github.com/discourse/discourse_docker
  [man]: https://mandrillapp.com
  [ssh]: https://help.github.com/articles/generating-ssh-keys
 [meta]: https://meta.discourse.org
   [do]: https://www.digitalocean.com/
  [lts]: https://wiki.ubuntu.com/LTS
  [jet]: http://www.mailjet.com/pricing
  [gun]: http://www.mailgun.com/
  [put]: http://www.chiark.greenend.org.uk/~sgtatham/putty/download.html

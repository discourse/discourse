The [Discourse Docker Image][dd] makes it easy to set up Discourse on a cloud server. In this guide I'll assume that you are using [Digital Ocean][do], although these steps will work on other similar services.

The below guide assumes that you have no knowledge of Ruby/Rails or Linux shell, so it will be detailed. Feel free to skip steps which you are comfortable with.

# Create New Digital Ocean Droplet

Discourse recommends a minimum of 1 GB RAM. We'll use "discourse" as the Hostname.

<img src="https://meta-discourse.r.worldssl.net/uploads/default/3398/975dbf6267b4ad4f.png" width="690" height="475"> 

Install Discourse on Ubuntu 12.04.3 LTS x64. We always recommend using [the current LTS distribution][lts].

<img src="https://meta-discourse.r.worldssl.net/uploads/default/3399/f3fc67ee6aa90ea4.png" width="690" height="477"> 

You will receive a mail from Digital Ocean with the root password to your Droplet. (However, if you use SSH keys, you may not need a password to log in.)

# Access Your Droplet

Connect to your Droplet via SSH:

    ssh root@192.168.1.1

(Alternately, use [Putty][put] on Windows)

Replace `192.168.1.1` with the IP address of your Droplet.

<img src="https://meta-discourse.r.worldssl.net/uploads/default/2999/0934a0158459ec3f.png" width="571" height="130"> 

It will ask your permission to connect, type `yes`, then it will ask for the root password, which is in the email Digital Ocean sent you when the Droplet was set up. Enter it.

<img src="https://meta-discourse.r.worldssl.net/uploads/default/3000/8209c1e40c9d70a8.png" width="570" height="278"> 

# Install Git

    sudo apt-get install git

<img src="https://meta-discourse.r.worldssl.net/uploads/default/3002/eafbf14df8eee832.png" width="572" height="263"> 

# Generate SSH Key

**We highly recommend setting a SSH key, because you may need to access the Rails console for debugging purposes. This is only possible if you have SSH access preconfigured. This <i>cannot</i> be done after bootstrapping the app.**

    ssh-keygen -t rsa -C "your_email@example.com"

(We want the default settings, so when asked to enter a file in which to save the key, just press <kbd>enter</kbd>. Via [GitHub's SSH guide][ssh].)

# Install Docker

    sudo apt-get update
    sudo apt-get install linux-image-generic-lts-raring linux-headers-generic-lts-raring

<img src="https://meta-discourse.r.worldssl.net/uploads/default/3001/e94722e882f28994.png" width="566" height="339"> 

Reboot the server:

    sudo reboot

<img src="https://meta-discourse.r.worldssl.net/uploads/default/3003/d3cc759ced335d25.png" width="532" height="155"> 

This will log you out from your SSH session, so SSH in again:

    ssh root@192.168.1.1

Replace `192.168.1.1` with the IP address you got from Digital Ocean.

Finish installing Docker:

    sudo wget -qO- https://get.docker.io/ | sh

<img src="https://meta-discourse.r.worldssl.net/uploads/default/3004/e75967a1a8e27ea3.png" width="567" height="307"> 

# Install Discourse

Create a `/var/docker` folder where all the Docker related stuff will reside:

    mkdir /var/docker

Clone the [Official Discourse Docker Image][dd] into this `/var/docker` folder:

    git clone https://github.com/SamSaffron/discourse_docker.git /var/docker

Switch to your Docker directory:

    cd /var/docker

Copy the `samples/standalone.yml` file into the `containers` folder as `app.yml`, so the path becomes `containers/app.yml`:

    cp samples/standalone.yml containers/app.yml

<img src="https://meta-discourse.r.worldssl.net/uploads/default/3005/5c253f4657e2133f.png" width="571" height="56"> 

Modify this newly copied `app.yml`:

    nano containers/app.yml

(We recommend Nano because it works like a typical GUI text editor, just use your arrow keys. Hit <kbd>Ctrl</kbd><kbd>O</kbd> then <kbd>Enter</kbd> to save and <kbd>Ctrl</kbd><kbd>X</kbd> to exit. However, feel free to choose whatever text editor you like. In the below screenshot we use Vim.)

<img src="https://meta-discourse.r.worldssl.net/uploads/default/3006/ed9f51b3a44f2b86.png" width="572" height="451"> 

Modify the file as desired, but at minimum you should set `DISCOURSE_DEVELOPER_EMAILS` and `DISCOURSE_HOSTNAME`.

<img src="https://meta-discourse.r.worldssl.net/uploads/default/2979/e6fedbde9b471880.png" width="565" height="172"> 

I renamed `DISCOURSE_HOSTNAME` to `discourse.techapj.com`, this means that I want to host my instance of Discourse on `http://discourse.techapj.com/`. You'll need to modify your DNS records to reflect the IP address and preferred domain name of your server.

# Mail Setup

**Email is critical to Discourse. We strongly recommend configuring mail settings before bootstrapping.**

- If you already have a mail server, put your existing mail server credentials in the `app.yml` file.

- Otherwise, create a free account on [**Mandrill**][man] (or [Mailgun][gun], or [Mailjet][jet]), and put your Mandrill credentials (available via the Mandrill dashboard) in the `app.yml` file. The settings you want to change are `DISCOURSE_SMTP_ADDRESS`, `DISCOURSE_SMTP_PORT`, `DISCOURSE_SMTP_USER_NAME`, `DISCOURSE_SMTP_PASSWORD`.

# Add Your SSH Key

If you successfully generated the SSH key as described earlier, get it:

    cat ~/.ssh/id_rsa.pub

Copy the entire output and paste it into the `ssh_key` setting in the `app.yml` file.

# Bootstrap Discourse

Be sure to save the `app.yml` file, and begin bootstrapping Discourse:

    sudo ./launcher bootstrap app

<img src="https://meta-discourse.r.worldssl.net/uploads/default/3007/c0596ad3d330ae71.png" width="567" height="138"> 

This command may take some time, so be prepared to wait. It is automagically configuring your Discourse environment.

After that completes, start Discourse:

    sudo ./launcher start app

<img src="https://meta-discourse.r.worldssl.net/uploads/default/3008/ced00cf4782f020c.png" width="568" height="137"> 

Congratulations! You now have your own instance of Discourse, accessible via the domain name you entered in `app.yml` earlier.

<img src="https://meta-discourse.r.worldssl.net/uploads/default/3397/ea8c3de3a4b7361d.png" width="690" height="207"> 

You can also access it by visiting the server IP address directly, e.g. `http://192.168.1.1`.

# Log In and Become Admin

Sign into your Discourse instance. If you configured `DISCOURSE_DEVELOPER_EMAILS` and your email matches, your account will be made Admin by default.

If your account was not made admin, try SSH'ing into your container (assuming you entered your SSH key in the `app.yml` file):

    ./launcher ssh my_container
    sudo -iu discourse
    cd /var/www/discourse
    RAILS_ENV=production bundle exec rails c
    u = User.last
    u.admin = true
    u.save

This will manually make the first user an admin.

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

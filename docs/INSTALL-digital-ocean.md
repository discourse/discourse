The deployment of Discourse is simple thanks to the [Docker Image][1], all you need is SSH access to a virtual cloud server. In this guide I'll assume that you are using [Digital Ocean][do], although these steps will work on other cloud servers as well.

The below guide assumes that you have no knowledge of Ruby/Rails or Linux shell, so it will be detailed. Feel free to skip steps which you think you are comfortable with.

# Create new Digital Ocean Droplet

Discourse recommends a minimum of 1 GB Ram, so that's what we will go with. We'll use discourse as the Hostname.

<img src="https://meta-discourse.r.worldssl.net/uploads/default/2997/c453053824cef71a.png" width="690" height="457"> 

We will install Discourse on Ubuntu 12.04.3 x64 LTS as this is [recommended][2] in [official documentation][3].

<img src="https://meta-discourse.r.worldssl.net/uploads/default/2998/0084fb4e84c1d812.png" width="690" height="404"> 

Once you complete the above steps you will receive a mail from Digital Ocean with the root password to the Droplet. (However, if you entered your SSH keys, you won't need a password to log in).

# Access your newly created Droplet

To access the Droplet, type the following command in your terminal:

    ssh root@192.168.1.1

Replace `192.168.1.1` with the IP address you got from Digital Ocean.

<img src="https://meta-discourse.r.worldssl.net/uploads/default/2999/0934a0158459ec3f.png" width="571" height="130"> 

It will ask your permission to connect, type `yes`, then it will ask for the root password. The root password is in the email Digital Ocean sent you when the Droplet was set up. Type in that password to log in to your newly installed Ubuntu Server.

<img src="https://meta-discourse.r.worldssl.net/uploads/default/3000/8209c1e40c9d70a8.png" width="570" height="278"> 

# Install Git

To install Git:

    sudo apt-get install git

and you are good to go.

<img src="https://meta-discourse.r.worldssl.net/uploads/default/3002/eafbf14df8eee832.png" width="572" height="263"> 

# Generate SSH Key

** We highly recommend setting a SSH key, because you may need to access the Rails console for debugging purposes. This is only possible if you have SSH access preconfigured. It cannot be done after bootstrapping the app. **

Generate the SSH key:

    ssh-keygen -t rsa -C "your_email@example.com"
    ssh-add id_rsa

(We want the default settings, so when asked to enter a file in which to save the key, just press enter. Taken from [this guide][7])

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

Type in following commands:

    sudo sh -c "wget -qO- https://get.docker.io/gpg | apt-key add -"
    sudo sh -c "echo deb http://get.docker.io/ubuntu docker main\
    > /etc/apt/sources.list.d/docker.list"
    sudo apt-get update
    sudo apt-get install lxc-docker

<img src="https://meta-discourse.r.worldssl.net/uploads/default/3004/e75967a1a8e27ea3.png" width="567" height="307"> 

# Install Discourse

Congratulations! You've done all the hard work, now you have a brand new Ubuntu Server with Docker installed. Now let's install Discourse.

Create a `/var/docker` folder where all the docker related stuff will reside:

    mkdir /var/docker

Clone the [Official Discourse Docker Image][4] in `/var/docker` folder:

    git clone https://github.com/SamSaffron/discourse_docker.git /var/docker

*Make sure to copy and run the above command as is, otherwise you will face [problem][5] which I faced.*

Switch to the Docker directory:

    cd /var/docker

Copy the `samples/standalone.yml` file into the `containers` folder as `app.yml`, so the path becomes `containers/app.yml`:

    cp samples/standalone.yml containers/app.yml

<img src="https://meta-discourse.r.worldssl.net/uploads/default/3005/5c253f4657e2133f.png" width="571" height="56"> 

Modify the newly copied `app.yml` with our default variables:

    nano containers/app.yml

(We recommend Nano because it works like a text editor, just use your arrow keys. Hit `Ctrl-O` to save and `Ctrl-X` to exit. However, you can use whatever text editor you like. In the below screenshot we use Vim.)

You will see something like:

<img src="https://meta-discourse.r.worldssl.net/uploads/default/3006/ed9f51b3a44f2b86.png" width="572" height="451"> 

Modify the file as desired, but for the sake of simplicity I will only modify two variables `DISCOURSE_DEVELOPER_EMAILS` and `DISCOURSE_HOSTNAME`.

<img src="https://meta-discourse.r.worldssl.net/uploads/default/2979/e6fedbde9b471880.png" width="565" height="172"> 

Notice that I renamed `DISCOURSE_HOSTNAME` to `discourse.techapj.com`, this means that I want to host my instance of Discourse on `http://discourse.techapj.com/`, for this to work properly you will need to modify your DNS records.

#Mail Setup

**This step is required to successfully set up mail settings for Discourse.**

We recommended setting mail settings before bootstrapping your app. If you are an advanced user, put your mail credentials in the `app.yml` file.

If you are a beginner, create a free account on [**Mandrill**][6], and put your Mandrill credentials (available on the Mandrill Dashboard) in the above file. The settings you want to change are `DISCOURSE_SMTP_ADDRESS`, `DISCOURSE_SMTP_PORT`, `DISCOURSE_SMTP_USER_NAME`, `DISCOURSE_SMTP_PASSWORD`.

#Add SSH Key

If you successfully generated the SSH key as described earlier, get the generated key:

    cat ~/.ssh/id_rsa.pub

Copy the entire output and paste it into the `ssh_key` setting in the `app.yml` file.

# Bootstrap Discourse

Save the `app.yml` file, and begin bootstrapping Discourse:

    sudo ./launcher bootstrap app

<img src="https://meta-discourse.r.worldssl.net/uploads/default/3007/c0596ad3d330ae71.png" width="567" height="138"> 

This command may take some time, but it's doing all the hard work for you. This command is automagically configuring your Discourse environment.

After that completes, start Discourse:

    sudo ./launcher start app

<img src="https://meta-discourse.r.worldssl.net/uploads/default/3008/ced00cf4782f020c.png" width="568" height="137"> 

Congratulations! You have your own live instance of Discourse running on the host you provided in `app.yml` file at the time of setup.

<img src="https://meta-discourse.r.worldssl.net/uploads/default/3009/5c7b0accf602dcca.png" width="689" height="246"> 

*You can also access your instance of Discourse by visiting your `IP_ADDRESS`.*

# Access Admin

Sign into your Discourse instance. If you configured `DISCOURSE_DEVELOPER_EMAILS` and your email matches, your account will be made Admin by default.

In case your account is not made admin (reported by some users), try SSH'ing into your container (assuming you entered your SSH key in the `app.yml` file):

    ./launcher ssh my_container
    sudo -iu discourse
    cd /var/www/discourse
    RAILS_ENV=production bundle exec rails c
    u = User.last
    u.admin = true
    u.save

Voilà, you are now the admin of your own Discourse installation!

If anything needs to be improved in this guide, feel free to ask on [meta.discourse.org][8], or even better, submit a pull request.

  [1]: https://github.com/discourse/discourse_docker
  [2]: https://github.com/discourse/discourse_docker#important-before-you-start
  [3]: https://github.com/discourse/discourse_docker#about
  [4]: https://github.com/discourse/discourse_docker
  [5]: https://meta.discourse.org/t/error-while-deploying-discourse-to-digital-ocean-using-docker/12126/27
  [6]: https://mandrillapp.com
  [7]: https://help.github.com/articles/generating-ssh-keys
  [8]: https://meta.discourse.org
 [do]: https://www.digitalocean.com/

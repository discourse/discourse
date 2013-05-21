# Discourse Developer Install Guide (Vagrant)

### If you are on a Mac or PC, please try our [Discourse as Your First Rails App](http://blog.discourse.org/2013/04/discourse-as-your-first-rails-app/) blog post first!

(If you have experience setting up Rails projects, you might want to take a look at our **[Discourse Advanced Developer Guide](https://github.com/discourse/discourse/blob/master/docs/DEVELOPER-ADVANCED.md)**. It also contains instructions on building your own Vagrant VM.)

The following instructions will automatically download and provision a virtual machine for you to begin hacking
on Discourse with:

### Getting Started

1. Install Git: http://git-scm.com/downloads (or [GitHub for Windows](http://windows.github.com/) if you want a GUI)
2. Install VirtualBox: https://www.virtualbox.org/wiki/Downloads
3. Install Vagrant: http://www.vagrantup.com/ (We require Vagrant 1.1.2+ or later)
4. Open a terminal
5. Clone the project: `git clone https://github.com/discourse/discourse.git`
6. Enter the project directory: `cd discourse`

### Using Vagrant

When you're ready to start working, boot the VM:
```
vagrant up
```

Vagrant will prompt you for your admin password. This is so it can mount your local files inside the VM for an easy workflow.

(The first time you do this, it will take a while as it downloads the VM image and installs it. Go grab a coffee.)

If you would like to download a smaller VM (574MB instead of 935MB), or if you are having **trouble** downloading the VM:
- Download this file: http://www.discourse.org/vms/discourse-0.8.4.box.7z using your favorite web browser/download tool.
- If you don't have 7z available, you can still get the larger image from http://www.discourse.org/vms/discourse-0.8.4.box
- Extract it using 7z: `7z e discourse-0.8.4.box.7z`
- Add it to vagrant: `vagrant box add discourse-0.8.4 /path/to/the/downloaded/discourse-0.8.4.box virtualbox`.

**Note to Linux users**: Your Discourse directory cannot be on an ecryptfs mount or you will receive an error: `exportfs: /home/your/path/to/discourse does not support NFS export`

**Note to OSX/Linux users**: Vagrant will mount your local files via an NFS share. Therefore, make sure that NFS is installed or else you'll receive the error message:

```
Mounting NFS shared folders failed. This is most often caused by the NFS
client software not being installed on the guest machine. Please verify
that the NFS client software is properly installed, and consult any resources
specific to the linux distro you're using for more information on how to
do this.
```

For example, on Ubuntu, you can install NFS support by installing nfs-kernel-server with `apt-get install`.

Once the machine has booted up, you can shell into it by typing:

```
vagrant ssh
```

The discourse code is found in the /vagrant directory in the image.

**Note to Windows users**: You cannot run ```vagrant ssh``` from a cmd prompt; you'll receive the error message:

```
`vagrant ssh` isn't available on the Windows platform. You are still able
to SSH into the virtual machine if you get a Windows SSH client (such as
PuTTY). The authentication information is shown below:

Host: 127.0.0.1
Port: 2222
Username: vagrant
Private key: C:/Users/Your Name/.vagrant.d/insecure_private_key
```

At this point, you will want to get an SSH client, and use it to connect to your Vagrant VM instead. We recommend
PuTTY:

**[PuTTY Download Link](http://www.chiark.greenend.org.uk/~sgtatham/putty/download.html)**

You may use this client to connect to the VM by using ```vagrant/vagrant``` as your username/password, or by [using
PuTTYGen to import the insecure_private_key file](http://jason.sharonandjason.com/key_based_putty_logins_mini_how_to.htm)
(mentioned above) into a PuTTY profile to quickly access your VM.

### Keeping your VM up to date

Now you're in a virtual machine is almost ready to start developing. It's a good idea to perform the following instructions
*every time* you pull from master to ensure your environment is still up to date.

```
cd /vagrant
bundle install
bundle exec rake db:migrate
bundle exec rake db:seed_fu
```

### Starting Rails

Once your VM is up to date, you can start a rails instance using the following command from the /vagrant directory:

```
bundle exec rails s
```

In a few seconds, rails will start serving pages. To access them, open a web browser to [http://localhost:4000](http://localhost:4000) - if it all worked you should see discourse! Congratulations, you are ready to start working!

You can now edit files on your local file system, using your favorite text editor or IDE. When you reload your web browser, it should have the latest changes.

### Changing the Seed Data

By default, the Vagrant virtual machine comes seeded with test data. You'll have a few topics to play around with
and some user accounts. If you'd like to use the default production seed data instead you can execute the following
commands:

```
vagrant ssh
cd /vagrant
psql discourse_development < pg_dumps/production-image.sql
rake db:migrate
rake db:test:prepare
```

If you change your mind and want to use the test data again, just execute the above but using `pg_dumps/development-image.sql` instead.

### Guard + Rspec

If you're actively working on Discourse, we recommend that you run [Guard](https://github.com/guard/guard). It'll automatically run our unit tests over and over, and includes support
for live CSS reloading.

To use it, follow all the above steps. Once rails is running, open a new terminal window or tab, and then do this:

```
vagrant ssh
cd /vagrant
bundle exec rake db:test:prepare
bundle exec guard -p
```

Wait a minute while it runs all our unit tests. Once it has completed, live reloading should start working. Simply save a file locally, wait a couple of seconds and you'll see it change in your browser. No reloading of pages should be necessary for the most part, although if something doesn't update you should refresh to confirm.


### Sending Email

Mail is sent asynchronously by Sidekiq, so you'll need to have sidekiq running to process jobs. Run it with this command in the /vagrant directory:

```
bundle exec sidekiq
```

Mailcatcher is used to avoid the whole issue of actually sending emails: https://github.com/sj26/mailcatcher

To start mailcatcher, run the following command in the vagrant image:

```
gem install mailcatcher && mailcatcher --http-ip 0.0.0.0
```

Then in a browser, go to [http://localhost:4080](http://localhost:4080)

Sent emails will be received by mailcatcher and shown in its web ui.

### Shutting down the VM

When you're done working on Discourse, you can shut down Vagrant with:

```
vagrant halt
```


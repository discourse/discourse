# Discourse Developer Install Guide (Vagrant)

### If you are on a Mac or PC, please try our [Discourse as Your First Rails App](http://blog.discourse.org/2013/04/discourse-as-your-first-rails-app/) blog post first!

(If you have experience setting up Rails projects, you might want to take a look at our **[Discourse Advanced Developer Guide](DEVELOPER-ADVANCED.md)**. It also contains instructions on building your own Vagrant VM.)

The following instructions will automatically download and provision a virtual machine for you to begin hacking
on Discourse with:

### Getting Started

1. Install Git: http://git-scm.com/downloads (or [GitHub for Windows](http://windows.github.com/) if you want a GUI)
2. Install VirtualBox: https://www.virtualbox.org/wiki/Downloads
3. Install Vagrant: http://www.vagrantup.com/ (We require Vagrant 1.7.2 or later)
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

### Keeping your VM up to date (and first install)

Now you're in a virtual machine is almost ready to start developing. It's a good idea to perform the following instructions
*every time* you pull from master to ensure your environment is still up to date.

```
cd /vagrant
bundle install
bundle exec rake db:migrate
```

### Starting Rails

Once your VM is up to date, you can start a rails instance using the following command from the /vagrant directory:

```
bundle exec rails s
```

In a few seconds, rails will start serving pages. To access them, open a web browser to [http://localhost:4000](http://localhost:4000) - if it all worked you should see discourse! Congratulations, you are ready to start working!

If you want to log in as a user, a shortcut you can use in development mode is to follow this link to log in as `eviltrout`:

http://localhost:4000/session/eviltrout/become

You can now edit files on your local file system, using your favorite text editor or IDE. When you reload your web browser, it should have the latest changes.

### Tests

If you're actively working on Discourse, we recommend that you run rake autospec, which will run the specs.  It’s very, very smart. It’ll abort very long test runs. So if it starts running all of the specs and then you just start editing a spec file and save it, it knows that it’s time to interrupt the spec suite, run this one spec for you, then it’ll keep running these specs until they pass as well. If you fail a spec by saving it and then go and start editing around the project to try and fix that spec, it’ll detect that and run that one failing spec, not a hundred of them.

To use it, follow all the above steps. Once rails is running, open a new terminal window or tab, and then do this:

```
vagrant ssh
cd /vagrant
RAILS_ENV=test bundle exec rake db:migrate
bundle exec rake autospec p l=5
```

For more insight into testing Discourse, see [this discussion](http://rubyrogues.com/117-rr-discourse-part-2-with-sam-saffron-and-robin-ward/) with the Ruby Rogues.

### Sending Email

Mail is sent asynchronously by Sidekiq, so you'll need to have sidekiq running to process jobs. Run it with this command in the /vagrant directory:

```
bundle exec sidekiq
```

Mailcatcher is used to avoid the whole issue of actually sending emails: https://github.com/sj26/mailcatcher

Mailcatcher is already installed in the vm, and there's an alias to launch it:

```
mailcatcher --http-ip=0.0.0.0
```

Then in a browser, go to [http://localhost:4080](http://localhost:4080). Sent emails will be received by mailcatcher and shown in its web ui.

### Shutting down the VM

When you're done working on Discourse, you can shut down Vagrant with:

```
vagrant halt
```

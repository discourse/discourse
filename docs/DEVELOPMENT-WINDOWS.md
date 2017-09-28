# Developing In A Windows Environment

This guide will cover how to set up a Windows environment for Discourse development. By the end of the guide, you should have:

1. A Linux virtual machine set up to run Discourse.
2. A clone of Discourse in Windows, ready for development.
3. A SSH connection from Windows to the virtual machine.
4. An understanding of how to develop and see the changes in a browser.

>**NOTE:** This guide assumes that you will be installing Ubuntu Server and developing as much as possible in Windows. If you would like to work entirely within the VM using [Ubuntu Desktop](https://www.ubuntu.com/download/desktop), please follow this guide to set up the VM, then switch over to the [ Discourse Advanced Developer Install Guide](DEVELOPMENT-OSX-NATIVE.md).

## Requirements

1. Windows 7 or higher
2. [VirtualBox](https://www.virtualbox.org/) or similar VM software
3. Git on the command line, or a [Git GUI client](https://git-scm.com/download/gui/windows)
4. POSIX-compliant Windows shell such as [Git Bash](https://git-for-windows.github.io/) or [Cygwin](https://www.cygwin.com/)
5. [Ubuntu Server LTS](https://www.ubuntu.com/download/server) ISO image

>**NOTE**: Because Discourse uses Ruby gems that relies on system calls, you must run it within a full Linux environment. A POSIX environment such as Git Bash or Cygwin is not enough to run Discourse.

## Step 1: Create the Virtual Machine

1. Install VirtualBox and download the Ubuntu Server LTS image. Start VirtualBox:

![](./images/virtualbox1.png)

2. Click on the `New` button on the upper left. In the dialog that appears, enter a name for the VM. Change the `Type` to `Linux`, and the `Version` to `Ubuntu (64-bit)`, then click `Next`:

![](./images/virtualbox2.png)

3. Set the `RAM size` to `2048 MB`, then click `Next`:

![](./images/virtualbox3.png)

4. Select `Create a virtual hard disk now`, then click `Create`:

![](./images/virtualbox4.png)

5. Select `VDI (VirtualBox Disk Image)`, then click `Next`:

![](./images/virtualbox5.png)

6. Select `Dynamically allocated`, then click `Next`:

![](./images/virtualbox6.png)

7. Enter a name for the disk image file and change the `Disk Size` to `20.00 GB`, then click `Create`:

![](./images/virtualbox7.png)

8. The dialog will close and you should now see the virtual machine in the VirtualBox Manager list:

![](./images/virtualbox8.png)

9. We'll change some of the settings to make the Virtual Machine slightly faster. Click on the `Settings` gear button near the top left. A dialog should open:

![](./images/virtualbox9.png)

10. Click on `System` in the list on the left. Click on the `Processor` at the top of the right panel. Change the `Processor(s)` count to `2`:

![](./images/virtualbox10.png)

11. Click on `Storage` in the list on the left. Click on `Empty` under `Controller: IDE`, then click on the CD icon next to the `IDE Secondary Master`. A dropdown menu should appear:

![](./images/virtualbox11.png)

12. Click on `Choose Virtual Optical Disk File...`. In the file dialog that appears, select the Ubuntu Server LTS image that you downloaded earlier and click `Open`. The settings dialog should now show the image name under `Controller: IDE`:

![](./images/virtualbox12.png)

13. Click on `OK` to save the changes. You are now ready to install Ubuntu.

## Step 2: Install Ubuntu

1. Click on `Start` at the top of the VirtualBox Manager window. If you get a dropdown, select `Normal Start`:

![](./images/ubuntuinstall1.png)

2. A new window should open and the VM will boot up. Wait until it displays the Ubuntu installer's language selection page.

From here on out, you must use the arrow keys and tab to change your selection, and the enter key to confirm your selection. If they don't seem to be doing anything, make sure that you have the VirtualBox windows focused.

Choose the language you're most comfortable with, then press `Enter`:

![](./images/ubuntuinstall2.png)

3. Select `Install Ubuntu Server`, then press `Enter`:

![](./images/ubuntuinstall3.png)

4. You will see a black screen, followed by a second language selection menu. Select the language you're most comfortable with, then press `Enter`:

![](./images/ubuntuinstall4.png)

5. Select your region, then press `Enter`:

![](./images/ubuntuinstall5.png)

6. `Detect keyboard layout?` Select `No`. It's faster to pick your keyboard layout from a list than for the auto-detect to find it:

![](./images/ubuntuinstall6.png)

7. Select your keyboard layout, then press `Enter`. You will be asked for a sub-keyboard layout. Pick the closest matching one on the list, or the first item if you're unsure.

![](./images/ubuntuinstall7.png)

![](./images/ubuntuinstall7b.png)

8. The installer will take some time to configure some stuff. Eventually it will ask you to enter the `Hostname`. Enter a name, select `Continue`, and press `Enter`:

![](./images/ubuntuinstall8.png)

9. Enter your full name, select `Continue`, and press `Enter`. You don't have to enter your real name if you don't want to:

![](./images/ubuntuinstall9.png)

10. Enter a username for your account. This is the username you will use to log in with, so pick something easy to remember:

![](./images/ubuntuinstall10.png)

11. Enter a password for your account. Pick something simple because you will need to enter it multiple times later on. It does not need to be a secure password because the VM is only accessible on your local machine. Also enter the same password for the password verification screen:

![](./images/ubuntuinstall11.png)

![](./images/ubuntuinstall11b.png)

12. `Encrypt your home directory?` Select `No`. The VM is only run on your local machine, so there is no need for such security measures:

![](./images/ubuntuinstall12.png)

13. The installer will take some time to detect your timezone. `Is this timezone correct`? Select `Yes`.  It doesn't really matter if it's wrong; this is a development VM and accurate timestamps is not necessary:

>**NOTE:** If the timezone detection is taking too long, simply cancel it and manually select your timezone.

![](./images/ubuntuinstall13.png)

14. `Partitioning method`, select `Guided - use entire disk and set up LVM`:

![](./images/ubuntuinstall14.png)

15. Select the disk to partition. There should only be one option:

![](./images/ubuntuinstall15.png)

16. `Write the changes to disks and configure LVM?` Select `Yes`:

![](./images/ubuntuinstall16.png)

17. `Amount of volume group to use for guided partitoning`, the populated value should already be the maximum size of the disk, so just select `Continue`:

![](./images/ubuntuinstall17.png)

18. `Write the changes to disks?` Select `Yes`:

![](./images/ubuntuinstall18.png)

19. The installer will now take some time to install the system. Wait until it prompts you for the HTTP proxy information. Leave this blank and select `Continue`:

![](./images/ubuntuinstall19.png)

20. The installer will now take some time to configure apt. Wait until it asks how you want to manage upgrades on the system. Select `Install security updates automatically`:

![](./images/ubuntuinstall20.png)

21. `Choose the software to install`, select `PostgreSQL database` (needed by Discourse), `standard system utilities`, and `OpenSSH server` (needed to connect from Windows into the VM):

![](./images/ubuntuinstall21.png)

22. The installer will now take some time to install the selected software. Wait until it asks you to `Install the GRUB boot loader to the master boot record?` Select `Yes`:

![](./images/ubuntuinstall22.png)

23. The installer will now take some time to finish the install. Wait until it asks you to remove the installation media. Select `Continue` and the VM will reboot. It's not necessary to remove the installation media because the installer will eject the virtual CD drive:

![](./images/ubuntuinstall23.png)

24. When the VM has finished rebooting and starting up, you should be presented with the login screen:

![](./images/ubuntuinstall24.png)

Congratulations! You just finished installing Ubuntu on a VM!

## Step 3: Configuring the Ubuntu VM For Discourse

In order to set up the Ubuntu VM to run Discourse, we need to configure some VM settings to expose Discourse's services to Windows.

1. Clone Discourse from their [GitHub repo](https://github.com/discourse/discourse) to a folder on your local drive:

![](./images/configure1.png)

2. Go to the `VirtualBox Manager` and click on the `Settings` gear near the top left to open the Settings dialog:

![](./images/virtualbox8.png)

![](./images/virtualbox9.png)

3. We will now add a folder that's shared from the host OS (Windows) to the guest OS (Ubuntu). Click on `Shared Folders` in the list on the left. Click on the `Add Folder` button near the upper right:

![](./images/configure2.png)

4. A dialog will ask you to select the folder. Add the Discourse folder that you cloned in step 1 as the `Folder Path`. For `Folder Name` use something memorable; we will use this name in a later step. Leave both options unchecked; we don't want the folder to be read-only, and auto-mounting only works for Ubuntu Desktop:

![](./images/configure3.png)

5. Click OK to accept the changes and you should see an entry for the shared folder:

![](./images/configure4.png)

6. We will now set up network port forwarding. Click on `Network` in the list on the left. `Adapter 1` should be enabled and attached to `NAT`. Click on the `Advanced` dropdown to expand it, then click on the `Port Forwarding` button:

![](./images/configure5.png)

7. The port forwarding dialog should open. Click on the `Add` icon on the upper right and add the following rules, then click the `OK` button:

| Name | Protocol | Host IP | Host Port | Guest IP | Guest Port |
|------|----------|---------|-----------|----------|------------|
| SSH | TCP | 127.0.0.2 | 22 | | 22 |
| Discourse Server | TCP | | 3000 | | 3000 |
| Sidekiq | TCP | | 1080 | | 1080 |

![](./images/configure6.png)

8. Click the `OK` button on the settings page, which will bring you back to the VirtualBox Manager.

9. **Close the VirtualBox Manager**. Shut down the VM by clicking `Machine` in the menu bar and selecting `ACPI shutdown`:

![](./images/configure7.png)

10. We need to enable the ability to create symlinks in shared folders so that Discourse can be set up properly. Open up a Windows `Command Prompt`:

![](./images/configure8.png)

11. Run the following command, using the name of the VM that you set in Step 1.2 (in our case, `Ubuntu`). It will take a few moments to complete:

```
"c:\Program Files\Oracle\VirtualBox\VBoxManage" setextradata Ubuntu VBoxInternal2/SharedFoldersEnableSymlinksCreate/discourse 1
```

![](./images/configure9.png)

>**NOTE:** The symlinking feature is disabled by default as a security feature and must be enabled through the command line. With it enabled, malicious software can break out of the VirtualBox sandboxing by creating symlinks to Windows system folders and modify their contents. You must be extra careful about what you choose to run on this VM. **It is highly recommended** that you use this VM **only** for Discourse development.

12. You may now close the command prompt. We've enabled the symlink feature, but we also need to re-run the VirtualBox Manager as administrator for it to work:

![](./images/configure10.png)

13. Start the VM by clicking the `Start` button at the top. The VM will start up and eventually show the login screen:

![](./images/ubuntuinstall1.png)

![](./images/ubuntuinstall24.png)

You are now done configuring the Ubuntu VM for Discourse development, and are ready to install the necessary software.

## Step 4: Installing Software in Ubuntu VM For Discourse

We will use a POSIX-compliant shell and SSH into the VM. [Git Bash](https://git-for-windows.github.io/) will be used in this guide. We do not want to directly use the terminal in VM window; we use Git Bash instead because:

* It supports scrolling up to view the terminal history.
* It has copy-paste capability.
* It can be resized.
* The terminal font and font size can be changed.
* It is significantly quicker than the VM window when displaying large amounts of text.

>**NOTE:** You must keep the VM window open in order for it to keep running. **Do not close it!** You may notice the screen going black; this is normal and is just Ubuntu turning off the virtual monitor.

1. We first need to insert the VirtualBox guest additions CD image. In the VM window, click on the `Devices` menu item at the top and click on `Insert Guest Additions CD image...`:

![](./images/softwareinstall3.png)

>**NOTE:** You will not receive any feedback or confirmation after clicking `Insert Guest Additions CD image...` The menu will simply close and in the background, the CD image will be inserted into the virtual CD drive.

2. Run `Git Bash`:

![](./images/softwareinstall1.png)

![](./images/softwareinstall1b.png)

3. SSH into the virtual machine by typing in the following command. Use the `username` that you created when installing Ubuntu in `Step 2.10`:

```bash
ssh john@127.0.0.2
```

You will be asked to authorize the connection if this is your first time connecting. `Are you sure you want to continue connecting (yes/no)?` Type `yes`, then press `Enter`. You will then be asked for your password. Enter it and you should be logged into the system. You can confirm this by verifying that the prompt's `username@hostname` has changed to the username and hostname that you selected when installing the VM:

![](./images/softwareinstall2.png)

4. Back in Git Bash, type the following command to mount the CD image, and enter your password when prompted:

```bash
sudo mount /dev/cdrom /media/cdrom
```

![](./images/softwareinstall4.png)

5. Install the VirtualBox guest additions by running the following command (it will take some time to complete):

```bash
sudo /media/cdrom/VBoxLinuxAdditions.run
```

![](./images/softwareinstall5.png)

6. Next, we will add the repository for `rvm` and update `apt` so that it can be installed:

```bash
sudo apt-add-repository ppa:rael-gc/rvm -y
sudo apt update
```

>**NOTE:** If you are connected to a VPN, the `apt-add-repository` command may fail with the error `ERROR: '~rael-gc' user or team does not exist.` If so, disconnect from VPN and try again.

7.  Install some software that Discourse needs to run (this will take a while):

```bash
sudo apt install rvm libpq-dev redis-server imagemagick -y
```

8. Before we can use `rvm`, we first need to log out and back in:

```
logout
ssh john@127.0.0.2
```

![](./images/softwareinstall6.png)

9. Install `Ruby 2.3.4` using `rvm`. You will need to enter password:

```bash
rvm install 2.3.4
```

10. Now we need to mount the shared folder to a local folder in the VM. Create the folder, then mount the shared folder to it using the name that we set in Step 3.4 (in our case, `discourse`). The syntax is in the format `sudo mount -t <FILE SYSTEM> <SHARED FOLDER NAME> <LOCATION TO MOUNT>`:

```bash
mkdir ~/discourse
sudo mount -t vboxsf discourse ~/discourse
```

11. Every time the VM is restarted, the above `mount` command must be re-executed to re-mount the shared folder. This would be a pain to do by hand every time, so let's add it to our `.profile` file, which is executed each time we log in:

```bash
echo 'sudo mount -t vboxsf discourse ~/discourse' >> ~/.profile
```

>**NOTE:** After doing this, you will have to enter your password twice whenever you log in.

12. Change over to the `discourse` folder and install `bundler` and `mailcatcher`, then the gems needed by Discourse (this will take a while):

```bash
cd ~/discourse
gem install bundler mailcatcher
bundle install
```

13. Create the Discourse database using the `rake` task:

```bash
rake db:create
rake db:migrate
```

>**NOTE:** If you get an `failed to create symbolic link: <FILE PATH>: Protocol error` message, you need to run VirtualBox Manager as an administrator, as explained in Step 3.12.

14. Start up the Rails server, bound to 0.0.0.0 so that we can access it from the Windows side:

```bash
// TODO: Start sidekiq and mailcatcher
rails s -b 0.0.0.0
```

15. Using your browser, navigate to http://localhost:3000. It will take a while to load the page the first time, but once it does, you should see Discourse's successful installation screen:

![](./images/softwareinstall7.png)

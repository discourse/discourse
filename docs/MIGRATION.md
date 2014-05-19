So you want to move your existing Discourse instance to a new server? 

In this guide we'll move an existing Discourse instance on [Linode][linode] to a new Discourse instance on [Digital Ocean][do], although these steps will work on other cloud providers that also support Docker. Let's start!

## Log In as Admin on Existing Server

Only admins can perform backups, so sign in as an account with admin access on your existing Discourse instance on Linode.

<img src="https://meta-discourse.r.worldssl.net/uploads/default/5075/0900269482193379.png" width="690" height="367"> 

## Update Existing Install

Both the new and old Discourses **MUST BE ON THE EXACT SAME VERSION** to ensure proper backup/export. So the first thing we'll do is update our existing Discourse instance on Linode to the absolute latest version.

Visit `/admin/docker` to upgrade.

(If you are running the [deprecated Ubuntu install][dep_ubuntu] you may need to follow [these update instructions][ubuntu_update].)

<img src="https://meta-discourse.r.worldssl.net/uploads/default/5089/057a025f63a3f5fd.png" width="690" height="440"> 

After successfully upgrading, you should see *You're up to date!*

<img src="https://meta-discourse.r.worldssl.net/uploads/default/5077/e70d99317685541d.png" width="487" height="127"> 

## Download Your Backup

Visit `/admin/backups` and click **Backup** button.

<img src="https://meta-discourse.r.worldssl.net/uploads/default/5078/95678045bffdcd37.png" width="690" height="199"> 

You will be prompted for confirmation, press **Yes**.

<img src="https://meta-discourse.r.worldssl.net/uploads/default/5047/936eb2559f183fa2.png" width="690" height="180"> 

Once confirmed, you will be able to see the log of backup processing. Once the processing is finished, switch back to **Backups** tab.

<img src="https://meta-discourse.r.worldssl.net/uploads/default/5079/bbf134699e31579d.png" width="690" height="441"> 

Now you will see the newly created backup file. Click **Download** button and save the file, we will need it later for restoration on the new server.

<img src="https://meta-discourse.r.worldssl.net/uploads/default/5080/7acf53c2ee777b0c.png" width="690" height="229"> 

## Log In as Admin on New Server

Sign up and login on your new Discourse instance at Digital Ocean.

<img src="https://meta-discourse.r.worldssl.net/uploads/default/5081/d4c0d02f8e7c1922.png" width="689" height="288"> 

## Enable Restore

Under site settings search for `restore`:

<img src="https://meta-discourse.r.worldssl.net/uploads/default/5082/67dfcfca4c13d6fc.png" width="690" height="243"> 

Enable the `allow_restore` setting, and refresh the page for changes to take effect.

## Restore Backup

Browse to `/admin/backups` and click **Upload** button, select the backup file you downloaded previously from your existing Discourse instance (file name ends with `.tar.gz`):

<img src="https://meta-discourse.r.worldssl.net/uploads/default/5083/8077d61bf31be508.png" width="690" height="224"> 

Once the file gets uploaded it will be listed as shown below, click **Restore** button:

<img src="https://meta-discourse.r.worldssl.net/uploads/default/5084/01443ed902f43d4a.png" width="689" height="225"> 

Press **Yes** when prompted for confirmation:

<img src="https://meta-discourse.r.worldssl.net/uploads/default/5061/87202e56a402eb58.png" width="690" height="166"> 

You will see restore process log, it may take some time but it's automagically importing all your existing Discourse instance (Linode server) data.

<img src="https://meta-discourse.r.worldssl.net/uploads/default/5085/c397f8218cae2fc9.png" width="690" height="447"> 

Once the Restore process finishes, you will be logged out.

## Log In and You're Done

Once the restore process finishes, all the data from your previous Discourse instance on Linode server will be imported in your new Discourse instance on Digital Ocean, sign in with your Admin account and you are good to go!

<img src="https://meta-discourse.r.worldssl.net/uploads/default/5087/557688e5922a1ce4.png" width="690" height="375"> 

If anything needs to be improved in this guide, feel free to ask on [meta.discourse.org][meta].


  [do]:               https://www.digitalocean.com/?refcode=5fa48ac82415
  [dep_ubuntu]:       https://github.com/discourse/discourse/blob/master/docs/INSTALL-ubuntu.md
  [ubuntu_update]:    https://github.com/discourse/discourse/blob/master/docs/INSTALL-ubuntu.md#updating-discourse
  [official_install]: https://github.com/discourse/discourse/blob/master/docs/INSTALL.md
  [do_install]:       https://github.com/discourse/discourse/blob/master/docs/INSTALL-digital-ocean.md
  [linode]:           https://www.linode.com/
  [namecheap]:        https://www.namecheap.com/
  [meta]:             https://meta.discourse.org/t/move-your-discourse-instance-to-a-different-server/15721
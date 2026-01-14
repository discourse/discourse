# Official Discourse Advertising Plugin

Official Plugin Topic & Documentation: https://meta.discourse.org/t/official-advertising-ad-plugin-for-discourse/33734

This is the official Discourse advertising plugin.  It allows advertisements to be served by supported advertising platforms for users with a Discourse forum.

**Authors**: 		[Sarah Ni](https://github.com/cyberkoi) & [Vi Nguyen](https://github.com/ladydanger)

**Version**: 			1.2.5

**Contributors**: See [credits section](#credits)  below

**License**: 			MIT License

**Supported Discourse Version**: 1.4

**Supported Ad Platforms**:
* House Ads: Your own ads served from Discourse
* [Google Adsense](http://www.google.com.au/adsense/start/why-adsense.html)
* [Google Double Click for Publishers](https://www.google.com/dfp)
* [Amazon Affiliates](http://affiliate-program.amazon.com) - Banner and Product Link Ads
* [Carbon Ads](https://www.carbonads.net/)
* [AdButler](https://www.adbutler.com/)


## Quick Start in 3 Steps

This quick start shows you how to install this plugin and use it.  Recommended if you have:

* A live discourse forum
* You have deployed your live forum using Docker.  If you're using Digital Ocean, it's likely that your forum is deployed on Docker.

For non-docker or local development installation (those with programming experience), see **Other Installation**.


### Step 1 - Install the Official Discourse Advertising Plugin


As seen in a [how-to on meta.discourse.org](https://meta.discourse.org/t/install-plugins-in-discourse/19157), simply **add the plugin's repository url to your container's app.yml file**:

```yml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - mkdir -p plugins
          - git clone https://github.com/discourse/discourse-adplugin.git
```
Rebuild the container

```
cd /var/discourse
git pull
./launcher rebuild app
```

### Step 2 - Configure Your Settings to Display Your Advertisments

There are 2 easy steps for configuring your Discourse settings to enable advertisements to display in your Discourse forum.

#### House Ads

If you don't want to use an external ad platform, but want to show your own ads, then House Ads are for you!
Define your ads by going to the Admin section of your Discourse forum, and go to the Plugins section.
On the left, you should see a link called "House Ads".

Begin by creating your ads. Give each a short descriptive name and enter the html for each.
Style them using a custom theme (Admin > Customize > Themes).
Lastly, click the Settings button in the House Ads UI and choose which of your ads to show in each of
the ad slots. The ads will start showing as soon as you add them to slots.


#### Step 2(a) - Choose Your Advertisement Platform

<ul>
<li>Navigate to the Admin section in your Discourse forum.</li>
<li>Click on Settings and a left vertical navigation bar should appear.</li>
<li>Choose your advertisement platform.</li>
<ul>
<li>House Ads - if you want to create and serve ads from your Discourse instance.</li>
<li>Adsense - if using Adsense as your advertisement platform.</li>
<li>DFP - if using the DoubleClick for Publishers advertisement platform.</li>
<li>Carbon Ads - if using the Carbon Ads advertisement platform.</li>
<li>AdButler - if using the AdButler advertisement platform.</li>
</ul>
</ul>

#### Step 2(b) - Input Your Details

1. Add in your publisher ID - your publisher ID can be obtained from your ad platform and can also be found in your ad tag (see pictures below).
2. Choose your trust level from the dropdown box.  This will only display ads to users with a certain level of trust.  For more details about trust levels go to the **Plugin Features** heading.
3. Get the Advertisement Tag from your Ad Platform - see the images below to see what a tag looks like.
4. Add parts of your ad code to Discourse's site settings for the locations you wish your ad to appear.  Refer to image for your ad platform to where parts of your ad tag should go.  For more detail about where the ad will appear
5. Choose Your Ad Size - this is the same size that you've put into your ad provider to create your ad.  Go to the **Plugin Features** heading to see a list of supported Ad sizes.

##### Adsense Advertisement Tag to Discourse's Site Settings

![image](https://user-images.githubusercontent.com/5862206/214489271-32ce230f-9f79-441e-9d7a-c5488ebb8c8a.png)

##### DoubleClick for Publishers' Advertisement Tag to Discourse's Site Settings

![image](https://user-images.githubusercontent.com/5862206/214489324-8554a996-1876-432b-a686-e1add3b96ec4.png)

##### Amazon Affiliates' Advertisement Tag to Discourse's Site Settings
Only for Product Link and Banner Ads.

![image](https://user-images.githubusercontent.com/5862206/214489360-8829291b-8571-4deb-a867-139e823ebdea.png)

##### Carbon Ads Script Tag to Discourse's Site Settings

![adpluginexample](https://user-images.githubusercontent.com/5862206/214489455-234a3812-3606-47bf-9e49-cdaa3d1e3b9c.png)

##### AdButler Ads Zone URL to Discourse's Site Settings

This plugin only support AdButler "Standard Zones". Text and VAST are not supported.

If you browse to a zone in the AdButler admin, then you can find the Publisher ID (PPPPPP) and the Zone ID (ZZZZZZ) in the URL of your browser's address bar:

`https://admin.adbutler.com/?ID=PPPPPP&p=textadzone.view&zoneID=ZZZZZZ`

Configure the ads in Admin > Settings > AdButler.
Enter the publisher id in the "adbutler publisher id" setting, and enter the Zone IDs in the different
zone id settings as desired.

By default, ads are assumed to be size 728 x 90, or 320 x 50 in mobile view.
To use different size ads, customize using CSS in your site's theme. Override the following CSS:

```css
.adbutler-ad {
  width: 728px;
  height: 90px;
}

.adbutler-mobile-ad {
  width: 320px;
  height: 50px;
}
```

### Step 3 - See Your Ad

Once you've configured your settings and your advertising platform has ads that are ready to serve, navigate to the page where you've inputted for the location and you should see ads.


## Plugin Features

In this section, we go into more detail on:
* Available Locations for Ad Display
* Trust Levels
* Personal messages
* Groups
* Categories
* Tags

### Available Locations for Ad Display

The following are available locations along with a description and an image showing their location within Discourse to display ads for all platforms.

| Location Name | Description |
| --- | --- |
| Topic List Top | Ad will appear at the header of Discourse homepage |
| Topic Above Post Stream | Ad will appear in the header of all Discourse forum topics |
| Topic Above Suggested | Ad will appear in the footer above suggested topics of all Discourse forum topics |
| Post Bottom & Nth Post | Ad will appear on the stipulated nth post within a topic.  So if you have 5 posts in a topic and you want the ad to display after on the 2nd post, put 2 in ```ad_platform_nth_post_code```. |

![adplugin2](https://user-images.githubusercontent.com/5862206/214489128-2e0a9520-ffa5-47a9-81f8-27609b2c9975.jpeg)

### Trust Levels

You can use the ```ad_platform_through_trust_level``` dropdown to disable ads for users above a certain trust levels. As a guide, choosing:

* 0 shows ads to users that are not logged in.
* 1 shows ads to users that are not logged in, and to new and basic users.
* 2 shows ads to members as well, but not to regulars and leaders.
* 3 shows ads to everyone, but not to leaders.
* 4 shows ads to everyone including leaders.

To find more about trust levels in Discourse, refer to [Discourse's posts on trust levels](https://meta.discourse.org/t/what-do-user-trust-levels-do/4924)

### Personal messages

By default, ads won't be shown in personal messages. To enable ads in personal messages, use the "no ads for personal messages" setting.

### Groups

To give some users an ad-free experience, put the users in groups and add those groups to the "no ads for groups" setting.

### Categories

To disable ads in certain categories, add them to the "no ads for categories" setting. Also consider using the "no ads for restricted categories" to disable ads in all categories that have read access restrictions.

### Tags

Individual topics can have ads disabled by using tags, and entering those tags in the "no ads for tags" setting. This is useful if some topics violate ad network policies.

## Other Installation

There are two sets of installation instructions:

1. Non-Docker Installation - If you have experience with programming.  This will set up this plugin as a git submodule in your Discourse directory.
2. Local Development - If you want develop locally and have experience with programming.  This will set up this plugin as a symlinked file in Discourse's plugin directory.

If you already have a live Discourse forum up, please go to the Quick Start heading above.


### 1. Non-docker installation


* Run `bundle exec rake plugin:install repo=https://github.com/discourse/discourse-adplugin.git` in your discourse directory
* In development mode, run `bundle exec rake assets:clean`
* In production, recompile your assets: `bundle exec rake assets:precompile`
* Restart Discourse


### 2. Local Development Installation


* Clone the [Discourse Adplugin Repo](http://github.com/team-melbourne-rgsoc2015/discourse-adplugin) in a new local folder.
* Separately clone [Discourse Forum](https://github.com/discourse/discourse) in another local folder and [install Discourse](https://meta.discourse.org/t/beginners-guide-to-install-discourse-on-ubuntu-for-development/14727).
* In your terminal, go into Discourse folder navigate into the plugins folder.  Example ```cd ~/code/discourse/plugins```
* Create a symlink in this folder by typing the following into your terminal
:
```
ln -s ~/whereever_your_cloned_ad_plugin_path_is .
For example: ln -s ~/discourse-plugin-test .
```
* You can now make changes in your locally held Discourse Adplugin folder and see the effect of your changes when your run ```rails s``` in your locally held Discourse Forum files.


## Questions or Want to Contribute?

Open an Issue on this repository to start a chat.


## Credits

**Discourse.org**: 		Thanks to our amazing mentor [@eviltrout](https://github.com/eviltrout) and the wonderful [Discourse team!](http://www.discourse.org/)

**Our Coaches**: 					Very special thank you to our coaches and honorary coach - [@georg](https://github.com/georg), [@betaass](https://github.com/betaass), [@adelsmee](https://github.com/adelsmee), [@davich](https://github.com/davich), [@link664](https://github.com/link664), [@tomjadams](https://github.com/tomjadams), [@compactcode](https://github.com/compactcode), [@joffotron](https://github.com/joffotron), [@jocranford](https://github.com/jocranford), [@saramic](https://github.com/saramic), [@madpilot](https://github.com/madpilot), [@catkins](https://github.com/catkins)

**Rails Girls**: 			Thanks [@sareg0](https://github.com/sareg0) and the Rails Girls Team for the opportunity to participate in Rails Girls Summer of Code 2015.
<p>To create this plugin we referenced the <a href="https://github.com/discourse/discourse-google-dfp">original dfp plugin</a> (created by <a href="https://github.com/nlalonde">@nlalonde</a>) and the <a href="https://meta.discourse.org/t/google-adsense-plugin/11763/133">adsense plugin</a>.</p>

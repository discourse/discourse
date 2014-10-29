Congratulations, you are now the proud owner of your very own [Civilized Discourse Construction Kit](http://www.discourse.org). :hatching_chick:

### Admin Dashboard

As an admin you have total control over this Discourse instance. Exercise your admin superpowers via the admin dashboard at

[**/admin**](/admin)

You can also access it via the "hamburger" <kbd>☰</kbd> menu in the upper right: Admin functions are generally marked with the wrench :wrench:  icon, so look for that.

### Enter Required Settings

Go to the [Required tab](/admin/site_settings/category/required) of the site settings and enter all the required fields. **Until you set these required fields, _your Discourse is broken!_** Go ahead and do that now.

We'll wait.

### Customize Logos and Colors

By default you get the standard "penciled in" Discourse logo. Look for the [**assets for the site design**](/t/assets-for-the-site-design) topic; follow the instructions there to upload your logos to that topic, and then paste the uploaded image paths into the required logo settings.

To quickly give your Discourse a distinctive look, without having to edit or understand CSS, create a new color scheme via [**Customize, Colors**](/admin/customize/colors).

You can also specify custom CSS and custom HTML headers/footers to further customize the look. One common request is a navigation header that takes you back to the parent site. Here is some example HTML to put in [**Customize, CSS/HTML**](/admin/customize/css_html) under "Header":

```
<div id="top-navbar" class="container">
<span id="top-navbar-links" style="height:20px;">
  <a href="http://example.com">Home</a> | 
  <a href="http://example.com/about/">About</a> | 
  <a href="http://example.com/news/">News</a> | 
  <a href="http://example.com/products/">Products</a> | 
  <a href="http://blog.example.com/blog">Blog</a> | 
  <a href="http://forums.example.com/">Forums</a>
</span>
</div>
```

### Establish Staff

Staff members are official representatives of this community. There are two kinds of Staff:

1. **Admins**, who can do anything and configure anything on this site. 
2. **Moderators**, who can edit all posts and users, but cannot add categories or change any site settings. 

You may want to grant other users staff abilities &ndash; to do so click the admin button :wrench: on their user page, then look for the grant buttons.

### Private or Public?

Discourse assumes you want a public discussion area. If you prefer a private one, change these [login site settings](/admin/site_settings/category/login):

- `must approve users`
- `login required`
- `invite only`

If you only want some parts of your site to be private, edit category permissions. You already have one private category: this topic is in it!

### Configure Login Methods

Users can log in with traditional local username and password accounts. You may want to add:

- [Google logins](https://meta.discourse.org/t/configuring-google-oauth2-login-for-discourse/15858)
- [Twitter logins](https://meta.discourse.org/t/configuring-twitter-login-for-discourse/13395)
- [Facebook logins](https://meta.discourse.org/t/configuring-facebook-login-for-discourse/13394)
- [GitHub logins](https://meta.discourse.org/t/configuring-github-login-for-discourse/13745)

If you want to get extra-fancy you can also [set up single-sign on](https://meta.discourse.org/t/official-single-sign-on-for-discourse/13045), or even [build your own login method](https://meta.discourse.org/t/login-to-discourse-with-custom-oauth2-provider/14717).

### Test Your Email

Email is required for new account signups and notifications. **Test your email to make sure it is configured correctly!**  Visit [the admin email settings](/admin/email), then enter an email address in the "email address to test" field and click <kbd>send test email</kbd>.

- You got the test email? Great! **Read that email closely**, it has important email deliverability tips. 
- You didn't get the test email? This means your users probably aren't getting any signup or notification emails either.

Email deliverability can be hard. We strongly recommend using dedicated email services like [Mandrill](http://mandrill.com), [MailGun](http://www.mailgun.com/), or [MailJet](http://www.mailjet.com/), which offer generous free plans that work fine for most communities.

If you'd like to enable *replying* to topics via email, [see this howto](https://meta.discourse.org/t/set-up-reply-via-email-support/14003).

### What and Who is this site for?

One of the default topics is [Welcome to Discourse](/t/welcome-to-discourse). This topic is pinned globally, so it will appear on the homepage, right at the top of the topic list, for all new users. Try viewing your site with incognito, inprivate, or anonymous mode enabled in your browser to see it how new users will.

Your welcome topic is important because it is the first thing you visitors will see:

- Where am I?
- Who are these discussions for?
- What can I [find here](https://www.youtube.com/watch?v=d0VNHe5fq30)?
- Why should I visit?

[Edit your welcome topic](/t/welcome-to-discourse) and write a **brief introduction to your community**. Think of it as your "elevator pitch" &ndash; how would you describe this site to a stranger on an elevator when you had about 1 minute to talk?

Note that pinning topics works a little differently in Discourse:

- Users can hide pins on topics once they have read them via the controls at the bottom of the topic, so they aren't always pinned forever for everyone.
- When you pin a topic, you can choose to pin it globally to all topic lists, or pin it only within its category.

If a pin isn't visible enough, you can also turn one single topic into a **banner**. The banner topic floats on top of all topics and all primary pages. Users can permanently dismiss this floating banner by clicking the &times; in the upper right corner.

To make (or remove) a pin or a banner, use the admin wrench at the top right or bottom of the topic.

### Set the Homepage

By default your homepage is a simple list of the latest posts.

We strongly recommend sticking with this homepage for small and medium communities until you start getting lots of new topics every day.

You can change the homepage to the Categories list by editing `top menu` in the [Basic Setup](/admin/site_settings/category/basic) site settings. Change it from the default of

`latest|new|unread|starred|top|categories`

to

`categories|latest|new|unread|starred|top`

That is, move categories from the far right to the far left -- that leftmost top menu item is your default homepage. 

### Build Your Own FAQ

Right now [your FAQ](/faq) is the same Creative Commons [universal rules of civilized discourse](http://blog.discourse.org/2013/03/the-universal-rules-of-civilized-discourse/) we provide to all Discourse installs. These built-in community guidelines are referenced a bunch of places; please *do* use them and refer to them often – they really work!

However, if you want to set up a more detailed FAQ dealing with the specifics of *your* community, here's how:

1. Create a new [meta topic](category/meta), titled "Frequently Asked Questions (FAQ)" or similar.

2. Use the admin wrench icon below the post to make it a wiki post. This means the post is now editable to any user with a trust level of 1 or higher.

3. Note the URL to that topic.

4. Paste that URL into the `faq url` setting in the admin site settings. This links your topic from the hamburger FAQ menu entry at the top right of every page.

Now you have a community FAQ for your site that is collaboratively editable, and linked from every page on the site. 

### Categories

You have three default categories:

1. [Meta](/category/meta) – general discussion about the site itself. [It's important!](https://meta.discourse.org/t/what-is-meta/5249)
2. [Lounge](/category/lounge) – a perk for users at trust level 3 and higher
3. [Staff](/category/staff) – visible only to staff (admins and moderators)

**Don't create too many initial categories**, as you can overwhelm your audience. You can always add more categories, and easily bulk recategorize topics later. It's better to figure out the organization as you go rather than assuming you'll get it all right from the beginning (hint: you won't).

To add a category, visit the [categories page](/categories), then click Create Category at the upper right. You can set security per-category so only certain groups of users can see topics in that category.

Every category has an initial "About this category" topic. This topic will be pinned to the top of the category, and the description you enter will be used in a bunch of places. Be sure to give your new category a good, clear description, so people understand what belongs there!

### File Uploads

Basic image uploads work fine out of the box stored locally, provided you have adequate disk space.

- If you'd like other sorts of files to be uploaded beyond just images, modify the [file settings](/admin/site_settings/category/files).

- If you'd rather store your images and files on Amazon S3, [follow this howto](http://meta.discourse.org/t/how-to-set-up-image-uploads-to-s3/7229).


### New User Sandbox and the Trust System

If your discussion area is be open to the public, new visitors will arrive that are initially strangers to the community. Discourse has a [trust system](https://meta.discourse.org/t/what-do-user-trust-levels-do/4924/2) where users can, over time, earn the trust of the community and gain abilities to assist in governing their community.

Discourse is designed to offer safe defaults for public communities, even with no active moderation. 

> **0 (new) &rarr; 1 (basic) &rarr; 2 (member) &rarr; 3 (regular) &rarr; 4 (leader)**

All new users start out in a sandbox with restrictions for everyone's safety. **Trust level 0 (new) users _cannot_** &hellip;

- post more than 2 hyperlinks
- post any images or file attachments
- send private messages
- flag posts or topics
- have actual links in the "about me" field of their profile
- @name mention more than 2 users in a post

Virtually every action a user can take is rate limited for safety, and especially so for new users. But don't worry, new users can [transition to trust level 1](https://meta.discourse.org/t/what-do-user-trust-levels-do/4924/2) in about 15 minutes.

These defaults are safe, but they may be too conservative for your site:

- If you are pre-vetting all users, or your site is private and you approve all new users manually, you can set everyone's `default trust level` to 1.

- You can relax individual new user restrictions. Search settings for `newuser`. Ones commonly adjusted are `newuser max images`, `newuser max replies per topic`, `newuser max links`.

### User Content Licensing

Out of the box, Discourse defaults to [Creative Commons licensing](https://creativecommons.org/).

> Your users will always retain copyright on their posts, and will always grant the site owner enough rights to include their content on the site.
>
> Who is allowed to republish the content posted on this forum?
> 
> 1. Only the author
> 2. Author and the owner of this forum
> 3. Anybody\*

Number 3 is the Discourse default &ndash; that's [Creative Commons BY-NC-SA 3.0](http://creativecommons.org/licenses/by-nc-sa/3.0/deed.en_US).

 If that's not what you want, edit the [Terms of Service](/tos) to taste via the edit link at the top.

### Building Your Community

Be patient! Building communities is hard. Before launching, be sure to:

1. Define your community's purpose in a pinned or banner topic.
2. Seed the discussion with interesting topics.
3. Commit to visiting and participating regularly.
4. Link your community everywhere and promote it so people can find it.

There's more advice at [Building a Discourse Community](http://blog.discourse.org/2014/08/building-a-discourse-community/).

### Sending Invitations

One way to get people to visit your site is to invite them via email. You can do this via:

- The Invite button at the bottom of the topic.
- The Invite area on your profile page.
 
The invite area on your profile page also includes advanced Staff methods of [sending bulk invites](https://meta.discourse.org/t/sending-bulk-user-invites/16468), and [inviting users into groups](https://meta.discourse.org/t/invite-individual-users-to-a-group/15544).

### Maintenance

- One CPU and 1GB of memory, with swap, is the minimum for a basic Discourse community. As your community grows you may need more memory or CPU resources.

- Hopefully you are running [in our Docker container install](https://github.com/discourse/discourse/blob/master/docs/INSTALL.md); it's the only one we officially support. It guarantees easy updates, and all recommended optimizations from the Discourse team.

- You should get an email notification when new versions of Discourse are released. To update your instance via our easy one click upgrade process, visit [/admin/upgrade](/admin/upgrade).

- Some other things you might eventually want to set up:
   - [Automatic daily backups](https://meta.discourse.org/t/configure-automatic-backups-for-discourse/14855)
   - [HTTPS support](https://meta.discourse.org/t/allowing-ssl-for-your-discourse-docker-setup/13847)
   - [Content Delivery Network support](https://meta.discourse.org/t/enable-a-cdn-for-your-discourse/14857) 
   - [Reply via Email](https://meta.discourse.org/t/set-up-reply-via-email-support/14003)   
   - [Import and Export your data](https://meta.discourse.org/t/move-your-discourse-instance-to-a-different-server/15721)
   - [Change the domain name](https://meta.discourse.org/t/how-do-i-change-the-domain-name/16098)
   - [Multiple Discourse instances on the same server](https://meta.discourse.org/t/multisite-configuration-with-docker/14084)
   - [Import old content from vBulletin, PHPbb, Vanilla, Drupal, BBPress, etc?](https://github.com/discourse/discourse/tree/master/script/import_scripts)?

### Need more Help?

For more assistance on configuring and running your Discourse forum, see [meta.discourse.org](http://meta.discourse.org).

----

Have suggestions to improve or update this guide? Submit a [pull request](https://github.com/discourse/discourse/blob/master/docs/ADMIN-QUICK-START-GUIDE.md).

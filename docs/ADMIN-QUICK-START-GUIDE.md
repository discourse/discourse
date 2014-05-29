Congratulations, you are now the proud owner of your very own [Civilized Discourse Construction Kit](http://www.discourse.org). :hatching_chick:

### Admin Dashboard

As an admin you have total control over this Discourse instance. Exercise your admin superpowers via the admin dashboard at

[**/admin**](/admin)

You can also access it via the "hamburger" menu in the upper right. Admin functions are generally marked with the wrench :wrench:  icon, so look for that.

You'll want to come back and spend time exploring your admin dashboard. But first, let's configure your Discourse.

### Enter Required Settings

Go to the [Required tab](/admin/site_settings/category/required) of the site settings and enter all the required fields. **Until you set these required fields, _your Discourse is broken!_**

### Customize Logos and Colors

By default you get the same standard generic "penciled in" Discourse logo everyone gets. Look for the [**assets for the forum design**](/t/assets-for-the-forum-design/5) topic; follow the instructions there to upload your logos to that topic, and then paste the uploaded image paths into the required logo settings.

To quickly give your Discourse a distinctive look, without having to edit or understand CSS, create a new color scheme via [Customize, Colors](/admin/customize/colors).

You can also specify custom CSS and custom HTML headers/footers to further customize the look. One common request is a navigation header that takes you back to the parent site. Here is some example HTML to put in [Customize, CSS and HTML Customizations](/admin/customize/css_html) under "Header":

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

You are the only staff member right now. Staff members are official representatives of this community:

1. **Admins**, who can do anything and configure anything on this site. 
2. **Moderators**, who can edit all posts and users, but cannot add categories or change any site settings. 

You may want to grant other users staff abilities &ndash; to do so click the admin button :wrench: on their user page, then look for the grant buttons.

### Private or Public?

Discourse assumes you want a public discussion area. If you prefer a private one, change these settings:

- `must_approve_users`
- `login_required`
- `invite_only`

If you only want some parts of your site to be private, edit permissions on a category. The built-in Staff category is an example.

### Configure Login Methods

By default, users can only log in with traditional local username and password accounts. Want more?

- [Configure Google logins](https://meta.discourse.org/t/configuring-google-oauth2-login-for-discourse/15858)
- [Configure Twitter logins](https://meta.discourse.org/t/configuring-twitter-login-for-discourse/13395)
- [Configure Facebook logins](https://meta.discourse.org/t/configuring-facebook-login-for-discourse/13394)
- [Configure GitHub logins](https://meta.discourse.org/t/configuring-github-login-for-discourse/13745)

If you want to get extra-fancy you can also [set up single-sign on](https://meta.discourse.org/t/official-single-sign-on-for-discourse/13045), or even [build your own oAuth 2 login](https://meta.discourse.org/t/login-to-discourse-with-custom-oauth2-provider/14717).

### Test Email

If email is not working, you have a broken Discourse &ndash; email is required for new account signups and notifications. **Test your email to make sure it is configured correctly!**  Visit [the admin email settings](/admin/email), then enter an email address in the "email address to test" field and click <kbd>send test email</kbd>.

- You got the test email? Great! **Read that email closely**, it has important email deliverability tips. 
- You didn't get the test email? This means your users probably aren't getting any signup or notification emails either.

Email deliverability can be hard. We strongly recommend using dedicated email services like [Mandrill](http://mandrill.com), [MailGun](http://www.mailgun.com/), or [MailJet](http://www.mailjet.com/), which offer generous free plans that work fine for most communities.

If you'd like to enable *replying* to topics via email, [see this howto](https://meta.discourse.org/t/set-up-reply-via-email-support/14003).

### What and Who is this site for?

One of the default topics is [Welcome to Discourse](/t/welcome/6). This topic is pinned globally, so it will appear on the homepage for all new users. Your welcome topic is important because it is the first thing you visitors will see:

- Where am I?
- Who is this discussion area for?
- What can I [find here](https://www.youtube.com/watch?v=d0VNHe5fq30)?
- Why should I visit here?

[Edit this welcome topic](/t/welcome/6) and write a **brief introduction to your community**. Think of it as your "elevator pitch" &ndash; how would you describe this site to a stranger on an elevator when you had about 1 minute to talk?

Note that pinning topics works a little differently in Discourse:

- Users can hide pins on topics once they have read them via the controls at the bottom of the topic, so they don't stay pinned forever for everyone.
- When you pin a topic, you can choose to pin it globally to all topic lists, or pin it only within its category.

### New User Sandbox and the Trust System

Discourse is designed to offer safe defaults for communities, even with no active moderation. There is a [trust system in Discourse](https://meta.discourse.org/t/what-do-user-trust-levels-do/4924/2) where regular users automatically earn abilities to assist in governing the community.

All new users start out at trust level zero, in a sandbox with restrictions for everyone's safety. **Trust level zero users _cannot_** &hellip;

- post more than 2 hyperlinks
- post any images or file attachments
- send private messages
- flag posts or topics
- have actual links in the "about me" field of their profile
- @name mention more than 2 users in a post

There are also a lot of rate limits around how many actions new users can take. Of course, new users don't stay new users forever; reading a variety of topics is enough to [transition to trust level 1](https://meta.discourse.org/t/what-do-user-trust-levels-do/4924/2) in about 15 minutes.

These defaults are safe, but they may be too conservative for your site:

- If you are pre-vetting users, or your site is private and you approve all new users manually, you can set everyone's `default trust level` to 1.

- You can individually adjust these conservative default new user restrictions. Search the settings for `newuser`. Two settings we see commonly adjusted are `newuser max images` and `newuser max replies per topic`.

### Categories

You have three categories out of the box:

1. [meta](/category/meta) – general discussion about the site itself. [It's important!](https://meta.discourse.org/t/what-is-meta/5249)
2. [lounge](/category/lounge) – a perk for users at trust level 3 and higher
3. [staff](/category/staff) – visible only to staff (admins and moderators)

**Don't create too many initial categories**, as you can overwhelm your audience. You can always add more categories later, and easily bulk recategorize topics any time. It's better to figure out organization as you go rather than assuming you'll get it all right from the beginning (hint: you won't).

To add a category, visit the [categories page](/categories), then click Create Category at the upper right. You can set security per-category so only certain groups of users can see topics in that category.

Every category has an initial "About the {foo} category" topic created alongside it. This topic will be pinned to the top of the category, and the description you enter here will be used in a bunch of places. Be sure to give your new category a good, clear description!

### File Uploads

Basic image uploads work fine out of the box stored locally, provided you have adequate disk space.

- If you'd like other sorts of files to be uploaded beyond just images, modify the [file settings](/admin/site_settings/category/files).

- If you'd rather store your images and files on Amazon S3, [follow this howto](http://meta.discourse.org/t/how-to-set-up-image-uploads-to-s3/7229).

### User Content Licensing

Out of the box, Discourse defaults to [Creative Commons licensing](https://creativecommons.org/).

> Your users will always retain copyright on their posts, and will always grant the forum owner enough rights to include their content on the forum.
>
> Who is allowed to republish the content posted on this forum?
> 
> 1. Only the author
> 2. Author and the owner of this forum
> 3. Anybody\*

Number 3 is the Discourse default &ndash; that's [Creative Commons BY-NC-SA 3.0](http://creativecommons.org/licenses/by-nc-sa/3.0/deed.en_US).

 If that's not what you want, please see our [admin User Content Licensing](/admin/site_contents/tos_user_content_license) page for a brief form that will let you cut and paste your decision into section #3 of the [Terms of Service](/tos#3). 

### Maintenance

- One CPU and 1GB of memory, with swap, is the minimum for a small Discourse community. As your community grows you may need more memory or CPU resources.

- Hopefully you are running [in our Docker container install](https://github.com/discourse/discourse/blob/master/docs/INSTALL.md); it's the only one we officially support. That will guarantee easy updates, and all recommended optimizations from the Discourse team.

- To upgrade your instance, visit [/admin/docker](/admin/docker). If there's a new version, an <kbd>upgrade</kbd> button will appear. Press it!

- Some other things you might eventually want to set up:
   - [Automatic daily backups](https://meta.discourse.org/t/configure-automatic-backups-for-discourse/14855)
   - [HTTPS support](https://meta.discourse.org/t/allowing-ssl-for-your-discourse-docker-setup/13847)
   - [Content Delivery Network support](https://meta.discourse.org/t/enable-a-cdn-for-your-discourse/14857) 
   - [Multiple Discourse instances on the same server](https://meta.discourse.org/t/multisite-configuration-with-docker/14084)
   - [Import and Export your data](https://meta.discourse.org/t/move-your-discourse-instance-to-a-different-server/15721)
   - [Change the domain name](https://meta.discourse.org/t/how-do-i-change-the-domain-name/16098)

### Need more Help?

For more assistance on configuring and running your Discourse forum, see [the support category](http://meta.discourse.org/category/support) or [the hosting category](http://meta.discourse.org/category/hosting) on [meta.discourse.org](http://meta.discourse.org).

This guide is a [work in progress](https://github.com/discourse/discourse/blob/master/docs/ADMIN-QUICK-START-GUIDE.md) and we hope to continually improve it with your feedback.
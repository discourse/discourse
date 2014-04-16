Congratulations, you are now the proud owner of your very own [Civilized Discourse Construction Kit](http://www.discourse.org). :hatching_chick:

Let's get started!

### Admin Dashboard

As an admin you have total control over this Discourse instance &mdash; and with great power comes great responsibility. Exercise your admin superpowers via the admin dashboard at

[**/admin**](/admin)

You can also access it via the "hamburger" menu in the upper right. Admin functions are generally marked with the wrench :wrench:  icon, so look for that.

Do come back and spend time exploring your admin dashboard. But first things first!

### Enter Required Settings

Go to the [Required tab](/admin/site_settings/category/required) of the site settings and enter all the required basic items. **Until you set these required values, _your Discourse is broken!_**

By default you get the same standard generic "penciled in" Discourse logo everyone gets. Look for the [**assets for the forum design**](/t/assets-for-the-forum-design/5) topic; follow the instructions there to upload your logos there, and then paste the uploaded image paths into the required logo settings.

### Establish Staff

You are the only staff member right now. Staff members are official representatives of this community:

- **Admins**, who can do anything and configure anything on this site. 
- **Moderators**, who can edit all posts and users, but cannot add categories or change any site settings. 

It's lonely at the top. You may want to grant other users moderator or admin &ndash; to do so click the admin button :wrench: on their user page, then look for the grant buttons.

### Private or Public?

Discourse assume you want a public discussion area. If you prefer a private one, be sure to check out these settings:

- `must_approve_users`
- `login_required`
- `invite_only`

You can also create private categories that are only visible to certain groups of users.

### Configure Login Methods

By default, people can log in with Google, Yahoo, and traditional local username and password accounts. Want more?

- [Configure Twitter logins](https://meta.discourse.org/t/configuring-twitter-login-for-discourse/13395)
- [Configure Facebook logins](https://meta.discourse.org/t/configuring-facebook-login-for-discourse/13394)
- [Configure GitHub logins](https://meta.discourse.org/t/configuring-github-login-for-discourse/13745)

### Test Email

**Test your email to make sure it is working!** Discourse relies heavily on email to notify people about conversations happening on the forum. Visit [the admin email settings](/admin/email), then enter an email address in the "email address to test" field and click <kbd>send test email</kbd>.

Did it work? Great! **Read this test email closely**, it has critical email deliverability tips. If you didn't get the test email, guess what? Your users probably aren't getting any email notifications, either. That's not good.

Email deliverability can be hard. We strongly recommend using dedicated email services like [Mandrill](http://mandrill.com), [MailGun](http://www.mailgun.com/), or [MailJet](http://www.mailjet.com/), which offer generous free plans that works fine for small forums.

If you'd like to enable replying to topics via email, [see this howto](https://meta.discourse.org/t/set-up-reply-via-email-support/14003).

### Categories

You have three categories out of the box:

1. [meta](/category/meta) – general discussion about the site itself. [It's important!](https://meta.discourse.org/t/what-is-meta/5249)
2. [lounge](/category/lounge) – a perk for users at trust level 3 and higher
3. [staff](/category/staff) – visible only to staff (admins and moderators)

Please **don't create too many initial categories**, as can easily overwhelm your audience. You can always add more categories later, and easily bulk recategorize topics any time. It's better to figure out organization as you go rather than assuming you'll get it all right from the beginning (hint: you won't).

To add a category, visit the [categories page](/categories), then click Create Category at the upper right. You can set security per-category so only certain groups of users can see topics in that category.

Every category has an initial "About the {foo} category" topic created alongside it. This topic will be pinned to the top of the category, and the description you enter here for the category will used in a bunch of places. So edit that first post and make the category description a good one!

### File Uploads

Basic image uploads work fine out of the box stored locally, provided you have adequate disk space.

- If you'd like other sorts of files to be uploaded beyond just images, modify the [file settings](/admin/site_settings/category/files).

- If you'd rather store your images and files on Amazon S3, [follow this howto](http://meta.discourse.org/t/how-to-set-up-image-uploads-to-s3/7229).

### Edit the Pinned Welcome Topic

One of the default topics you get is [Welcome to Discourse](/t/welcome/6). This topic is pinned globally, so it will appear on the homepage for all new users. Your welcome topic is hugely important – it tells visitors

- Who is this discussion area for? 
- What can they find here?
- Why should they visit here?

[Edit this welcome topic](/t/welcome/6) and write a **brief introduction to your community**. What is the "elevator pitch" &ndash; how would you describe this site to a stranger on an elevator when you had about 1 minute to talk?  What in the wide, wide world of sports is [going on here](https://www.youtube.com/watch?v=d0VNHe5fq30)?

Pinning topics works a little differently in Discourse:

- Users can hide pins on topics once they have read them, so they don't stay pinned forever for everyone.
- When you pin a topic, you can choose to pin it globally to all topic lists, or just pin it within its category.

### Customize CSS / Headers

You can specify custom CSS and custom HTML headers/footers to give your Discourse forum a unique look.

1. In the admin console, select "Customize".

2. Create a new site customization.

3. Enter a customization:
  - Custom CSS styles go in the "Stylesheet" section.
  - Custom HTML headers go in the "Header" section.
  - Ditto for mobile, except these only show up on detected mobile devices.

3. **Enable:** If you wish to have your styles and header take effect on the site, check the "Enable" checkbox, then click "Save". This is also known as "live reloading", which will cause your changes to take effect immediately.

4. **Preview:** If you wish to preview your changes before saving them, click the "preview" link at the bottom of the screen. Your changes will be applied to the site as they are currently saved in the "Customize" panel. If you aren't happy with your changes and wish to revert, simply click the "Undo Preview" link.

Here is some example HTML that would go into the "Header" section within "Customize":

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

### Set your Terms of Service and Content Licensing

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

- 1GB of memory, with swap, is the absolute minimum required for a small Discourse instance. If your community is expected to grow at all, have at least 2 GB of memory available. 

- Hopefully you are running [in our Docker container install](https://github.com/discourse/discourse/blob/master/docs/INSTALL.md); it's the only one we can officially support. That will guarantee you have easy updates, the correct version of Ruby, and all recommended optimizations from the Discourse team.

- To upgrade your instance, visit [/admin/docker](/admin/docker). Refresh the page a few times, and you will see an <kbd>upgrade</kbd> button appear. Press it! Then wait for the updating text at the bottom of the browser to know when you're done.

### Need more Help?

This guide is a [work in progress](https://github.com/discourse/discourse/blob/master/docs/ADMIN-QUICK-START-GUIDE.md) and we will be continually improving it with your feedback.

For more assistance on configuring and running your Discourse forum, see [the support category](http://meta.discourse.org/category/support) or [the hosting category](http://meta.discourse.org/category/hosting) on [meta.discourse.org](http://meta.discourse.org).
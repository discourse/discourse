Congratulations, you are now the proud owner of your very own [Civilized Discourse Construction Kit](http://www.discourse.org). :hatching_chick:

Let's get started!

### Admin Dashboard

To access the admin dashboard, click here:

[**/admin**](/admin)

You can access the Discourse admin dashboard at any time via the menu:

1. Click/tap the menu icon at the upper right.
2. Select Admin (it's the one with the wrench icon).

### Enter Required Settings

Go to the [Required tab](/admin/site_settings/category/required) of the Settings and change all the items there to taste.

By default you get the same standard generic "penciled in" Discourse logo everyone gets. That's not cool. You know what's cool? Your own logos and favicons. Look for the [**Assets for the forum design**](/t/assets-for-the-forum-design/5) topic. Upload your logos and favicon to that topic. (Note that you may need to edit the `authorized_extensions` setting to upload certain filetypes.)

Right click on the images in the post to get their URLs:

- Add the URL of the larger logo to the `logo_url`
- Add the URL of the smaller logo to the `logo_small_url`
- Add the URL of your favicon to the `favicon_url`

The admin dashboard will warn you about any essential settings you're missing. It's also a useful place to see:

- If problems are detected with your site settings or deployment
- If a new version of Discourse has been released
- General stats and metrics about the health of your forum

### Is this private or public?

Discourse works for both fully public discussion areas, and private ones that require explicit approval of every user. However, the defaults assume you want a public discussion area.

If you want a more private forum, be sure to check out these settings:

- `must_approve_users`
- `login_required`
- `invite_only`

You can also edit categories to only be visible to certain groups of users.

### Enable Logins

By default, people can log in here with local accounts, Google, or Yahoo. Some common forms of login require a bit of additional configuration: &hellip;

- **Twitter** &rarr; [walkthrough with screenshots](https://meta.discourse.org/t/configuring-twitter-login-for-discourse/13395)
- **Facebook** &rarr; [walkthrough with screenshots](https://meta.discourse.org/t/configuring-facebook-login-for-discourse/13394)
- **GitHub** &rarr; [walkthrough with screenshots](https://meta.discourse.org/t/configuring-github-login-for-discourse/13745)

### Creating New Categories

You'll have three categories by default

1. [meta](/category/meta) – general discussion about the site itself. [It's important!](https://meta.discourse.org/t/what-is-meta/5249)
2. [lounge](/category/lounge) – a perk for users at trust level 3 and higher
3. [staff](/category/staff) – for staff (admins and moderators), visible only to staff

Don't create too many categories initially, as it may overwhelm your audience. You can always add more later, and easily recategorize topics as they emerge.

To add a category, visit the [categories page](/categories), then click Create Category at the upper right. You can set security per-category so only certain groups of users can see topics in that category.

Every category has an initial "About the {foo} category" topic created alongside it. This topic will be pinned to the top of the category, and the description you enter here for the category will used in a bunch of places. So make it a good one!

### Configure File Uploads

Image uploads should work fine out of the box stored locally. You can also can configure it so that images users upload go to Amazon S3 by [following this howto](http://meta.discourse.org/t/how-to-set-up-image-uploads-to-s3/7229).

Attaching file types other than images to posts is also supported, read [the announcement](http://meta.discourse.org/t/new-attachments/8609) for details.

### Test Email

Discourse relies heavily on emails to notify people about conversations happening on the forum. Visit [the admin email settings](/admin/email), then enter an email address in the "email address to test" field and click <kbd>send test email</kbd>.

Did it work? Great! **Read this test email closely**, it has critical email deliverability tips. If you didn't get the test email, your users may not be getting any email notifications, either.

Also, achieving proper email deliverability can be hard. We strongly recommend something like [Mandrill](http://mandrill.com), [MailGun](http://www.mailgun.com/), or [MailJet](http://www.mailjet.com/), which solve email for you with virtually no effort, and offer generous free plans that works fine for small forums.

If you want to enable replying to topics via email, see the email settings section, specifically `reply_by_email_address`. This may require some mail server configuration.

### Edit the Welcome topic

One of the default topics you get is [Welcome to Discourse](/t/welcome-to-discourse). This topic will appear on the homepage for all new users. Your welcome topic is hugely important – it tells visitors

- Who is this forum for? 
- What can they find here?
- Why should they visit here?

Edit this topic and write a **brief introduction for your forum** that explains what the heck is going on here. Don't write a novel because nobody will read it. What is the "elevator pitch" for your forum? How would you describe this forum to a stranger on an elevator when you have about 1 minute to talk?

Also, you should know that **pinning topics works a little differently in Discourse** compared to other forums.

- Users can hide pins on topics once they have read them, so they don't stay pinned forever for everyone.
- Pinned topics with a category will only "stick" to the top of their category.
- Pinned topics with no category are pinned to the top of all topic lists.

### Set your Terms of Service and Content Licensing

Make sure you set your company name and domain variables for the [Terms of Service](/tos), which is a creative commons document.

You'll also need to make an important legal decision about the content users post on your forum:

> Your users will always retain copyright on their posts, and will always grant the forum owner enough rights to include their content on the forum.
>
> Who is allowed to republish the content posted on this forum?
>
> - Only the author
> - Author and the owner of this forum
> - Anybody

Please see our [admin User Content Licensing](/admin/site_contents/tos_user_content_license) page for a brief form that will let you cut and paste your decision into section #3 of the [Terms of Service](/tos#3).

### Customize CSS / Headers

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
<div id="top-navbar">
<span id="top-navbar-links" style="height:20px;">
  <a href="http://example.com">Home</a>
  <a href="http://example.com/about/">About</a>
  <a href="http://example.com/news/">News</a>
  <a href="http://example.com/products/">Products</a>
  <a href="http://blog.example.com/blog">Blog</a>
  <a href="http://forums.example.com/">Forums</a>
</span>
</div>
```

### Maintenance

- If your forum is expected to grow at all, be sure you have at least 2 GB of memory available to your Discourse instance. You might be able to squeak by with less, but we don't recommend it, unless you are an expert. 

- Hopefully you are running [in our Docker container install](https://github.com/discourse/discourse/blob/master/docs/INSTALL.md); it's the only one we can officially support. That will guarantee you have the correct version of Ruby and all recommended optimizations from the Discourse team.

- To upgrade your instance, visit [/admin/docker](/admin/docker). Refresh the page a few times, and you will see an <kbd>upgrade</kbd> button appear. Press it! Then wait for the updating text to know when you're done.

### Need more Help?

This guide is a [work in progress](https://github.com/discourse/discourse/blob/master/docs/ADMIN-QUICK-START-GUIDE.md) and we will be continually improving it with your feedback.

For more assistance on configuring and running your Discourse forum, see [the support category](http://meta.discourse.org/category/support) or [the hosting category](http://meta.discourse.org/category/hosting) on [meta.discourse.org](http://meta.discourse.org).

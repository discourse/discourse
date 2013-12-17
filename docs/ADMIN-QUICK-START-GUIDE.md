You are now the proud owner of your very own Civilized Discourse Construction Kit. Congratulations! As a new forum admin, here's a quick start guide to get you going:

### Login as an Admin

You can login via the blue "Log in" button in the upper-right hand corner of Discourse.

Not an admin? If you used the [official install guide](https://github.com/discourse/discourse/blob/master/docs/INSTALL-ubuntu.md) you can use the following commands (taken from that guide) to elevate your account privileges:

    # Run these commands as the discourse user
    cd ~/discourse
    # ~/discourse or /var/www/discouse depending on where discourse is installed
    RAILS_ENV=production bundle exec rails c

    # (in rails console)
    > me = User.find_by_username_or_email('myemailaddress@me.com')
    > me.activate #use this in case you haven't configured your mail server and therefore can't receive the activation mail.
    > me.admin = true
    > me.save

### Access the Admin Console<p>

To access the Discourse admin console, add `/admin` to the base URL, like so:

### http://discourse.example.com/admin

From here, you'll be able to access the Admin functions, all of which are very important, so do check each one out.

### Enable Twitter Logins

1. From the Administrative console above, enter **Site Settings**.
2. Scroll down to the two text fields named:

  `twitter_consumer_key`  
  `twitter_consumer_secret`  

3. Enter in your respective **key** and **secret** that is issued to you via dev.twitter.com. If you are unsure of what your key/secret is, or you have yet to obtain one, visit the Twitter Dev API FAQ on [how to obtain these keys](https://dev.twitter.com/docs/faq#7447).
4. In the Twitter settings, the callback url must use the path `/auth/twitter/callback` at your domain. e.g., `http://discuss.example.com/auth/twitter/callback`

### Enable Facebook Logins

1. From the Administrative console above, enter **Site Settings**.
2. Scroll down to the two text fields named:

  `facebook_app_id`  
  `facebook_app_secret`  

3. Enter in your respective **id** and **secret** that is issued to you via developers.facebook.com. If you are unsure of what your id/secret is, or you have yet to obtain one, visit the [Facebook Developers :: Access Tokens and Types](https://developers.facebook.com/docs/concepts/login/access-tokens-and-types/) page for more information.
4. In the Facebook App settings, you must enable "Website with Facebook Login" under "Select how your app integrates with Facebook" and set the Site URL to use the path `/auth/facebook/callback` at your site domain. e.g., `http://discuss.example.com/auth/facebook/callback`.

### Enable GitHub Logins<p>

1. From the Administrative console above, enter **Site Settings**.
2. Scroll down to the two text fields named:

  `github_client_id`  
  `github_client_secret`  

3. Enter in your respective **id** and **secret** that is issued to you via https://github.com/settings/applications/new. If you are unsure of what your id/secret is, or you have yet to obtain one, visit the [GitHub Developers :: Applications](https://github.com/settings/applications/) page for more information.
4. Be sure to set the Callback URL to use the path `/auth/github/callback` at your site domain. e.g., `http://discuss.example.com/auth/github/callback`.

### Creating New Categories<p>

You will get one new category by default, meta. [Check it out! It's important.](http://meta.discourse.org/category/meta) But you may want more.

Categories are the **colored labels** used to organize groups of topics in Discourse, and they are completely customizable:

1. Log in to Discourse via an account that has Administrative access.
2. Click the "Categories" button in the navigation along the top of the site.
3. You should now see a "Create Category" button at the top.
4. Select a name and set of colors for the category for it in the dialog that pops up.
5. Write a paragraph describing what the category is about in the first post of the Category Definition Topic associated with that category. It'll be pinned to the top of the category, and used in a bunch of places.

### File and Image Uploads

Image uploads should work fine out of the box, stored locally, though you can configure it so that images users upload go to Amazon S3 by [following this howto.](http://meta.discourse.org/t/how-to-set-up-image-uploads-to-s3/7229?u=codinghorror).

Attaching other file types is supported too, read [the announcement](http://meta.discourse.org/t/new-attachments/8609) for details.

### Test Email Sending

Discourse relies heavily on emails to notify folks about conversations happening on the forum. Visit [the admin email settings](/admin/email), then enter an email address in the "email address to test" field and click <kbd>send test email</kbd>. Did it work? Great! **Read this test email closely**, it has critical email deliverability tips. If you didn't get the test email, your users may not be getting any email notifications, either.

Also, achieving proper email deliverability can be hard. We strongly recommend something like [Mandrill](http://mandrill.com), which solves all this for you with virtually no effort, and has a generous free plan that works fine for small forums.

### Set your Terms of Service and User Content Licensing

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

### Customize CSS / Header Logos<p>

1. Access the Administrative console, and select "Customize".

2. You'll see a list of styles down the left-hand column, and two subcategories: "Stylesheet" and "Header".
  - Insert your custom CSS styles into the "Stylesheet" section.
  - Insert your custom HTML header into the "Header" section.

3. **Enable:** If you wish to have your styles and header take effect on the site, check the "Enable" checkbox, then click "Save". This is also known as "live reloading", which will cause your changes to take effect immediately.

4. **Preview:** If you wish to preview your changes before saving them, click the "preview" link at the bottom of the screen. Your changes will be applied to the site as they are currently saved in the "Customize" panel. If you aren't happy with your changes and wish to revert, simply click the "Undo Preview" link.

5. **Override:** If you wish to have your styles override the default styles on the site, check the "Override Default" checkbox.

Here is some example HTML that would go into the "Header" section within "Customize":

```
<div class='myheader' style='text-align:center;background-color:#CDCDCD'>
<a href="/"><img src="http://dummyimage.com/1111x90/CDCDCD/000000.jpg&text=Placeholder+Custom+Header" width="1111px" height="90px" border="0" /></a>    
</div>
```

### Write a welcome topic and pin it

What is this forum for? Who should visit? Write a **brief introductory topic for your forum** that explains what the heck is going on here, so new users who find your forum will have some idea what they're getting into, and what the purpose of your forum is. 

- Don't write a novel because nobody will read it. What is the "elevator pitch" for your forum? How would you describe this forum to a stranger on an elevator when you have about 1 minute to talk?
- do *not* give this topic a category!
- after creating the topic, click the wrench icon in the upper right to get the staff menu for the topic
- select Pin Topic

You should know that pinning topics works a little differently in Discourse than other forums. 

- Users can clear pins on topics once they have read them, so they don't stay pinned forever for everyone
- Pinned topics with a category will only "stick" to the top of their category
- Pinned topics with no category are pinned to the top of all topic lists

### Ruby and Rails Performance Tweaks<p>

- Be sure you have at least 2 GB of memory for your Discourse server. You might be able to squeak by with less, but we don't recommend it, unless you are an expert.

- We strongly advise setting `RUBY_GC_MALLOC_LIMIT` to something much higher than the default for optimal performance. See [this meta.discourse topic for more details][1]. 

### Need more Help?<p>

This guide is a work in progress and we will be continually improving it with your feedback.

For more assistance on configuring and running your Discourse forum, see [the support category](http://meta.discourse.org/category/support) or [the hosting category](http://meta.discourse.org/category/hosting) on meta.discourse.org.

[1]: http://meta.discourse.org/t/tuning-ruby-and-rails-for-discourse/4126
[2]: http://meta.discourse.org/category/support

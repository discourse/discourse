# encoding: utf-8
#
desc "Seed database for production"
task "db:seed:welcome" => :environment do
  [User, Category, Topic, Post].each do |klass|
    fail "Database already has some #{klass.name.pluralize}, aborting" if klass.exists?
  end

  include Rails.application.routes.url_helpers

  old_url_options = Rails.application.routes.default_url_options.clone

  host_names = ActiveRecord::Base.connection_pool.spec.config[:host_names]
  host = (host_names || []).first || "localhost"
  if Rails.env == "production" && host =~ /localhost/
    fail "Set the host_names in config/database.yml"
  end
  Rails.application.routes.default_url_options[:host] = host

  port = Rails.env == 'development' ? 3000 : 80
  Rails.application.routes.default_url_options[:port] = port

  ActiveRecord::Base.transaction do
    begin 
      # Not using admin:create cause it will become uneccessary complicated between handling passed args and user input
      admin = User.create!(email: "change_me@example.com", username: "forumadmin", password: "password")
      admin.grant_admin!
      admin.change_trust_level!(TrustLevel.levels.max_by{|k, v| v}[0])
      admin.email_tokens.update_all(confirmed: true) 

      meta = Category.create!(name: "meta", user: admin)
      definition = meta.topics.first.posts.first
      definition.raw = _meta_definition_raw # Text is at the end of this file
      definition.save!

      what_is_meta = PostCreator.create(admin, {
        raw: _what_is_meta_raw,
        reply_to_post_number: "", 
        category: "meta", 
        archetype: "regular",
        title: "Long title to pass validation"
      })

      fail "Failed to create post: \n #{p.errors.full_messages.join('\n')}" if what_is_meta.errors.present?

      what_is_meta.topic.update_status("pinned", true, admin)
      what_is_meta.topic.update_attribute(:title, "What is meta?")

      admin_guide = PostCreator.create(admin, {
        raw: _admin_guide_raw,
        reply_to_post_number: "",
        archetype: "regular",
        title: "The Discourse Admin Quick Start Guide",
        visible: true
      })

      fail "Failed to create admin guide:\n#{admin_guide.errors.full_messages.join('\n')}" if admin_guide.errors.present?
    ensure
      Rails.application.routes.default_url_options = old_url_options
    end
  end
end

  def _meta_definition_raw
    <<TEXT
Use the 'meta' category to discuss this forum -- things like deciding what sort of topics and replies are appropriate here, what the standards for posts and behavior are, and how we should moderate our community.
TEXT
  end

  def _what_is_meta_raw
    faq_url = faq_url()
    <<TEXT
Meta means discussion *of the discussion itself* instead of the actual topic of the discussion. For example, discussions about...

- The style of discussion.
- The participants in the discussion.
- The setting in which the discussion occurs.
- The relationship of the discussion to other discussions.

The etymology for the “meta-” prefix dates back to [Aristotle’s Metaphysics][1], which came after his works on physics. Meta means “after” in Greek. 

### Why do we need a meta category? ###

Meta is incredibly important. It is where communities come together to decide who they are and what they are *about*. It is where communities form their core identity and mission statement.

Meta is for the folks who enjoy the forum so much that they want to go beyond merely reading and posting -- they want to work together to improve their community in various ways. Meta is the place where all leadership and governance forms within a community, a way to debate and decide direction for the whole community.

Meta serves as *community memory*, documenting the history of the community and its culture. There's a story behind every evolution in rules or tone; these shared stories are what bind communities together. Meta also provides a home for all the tiny unique things that make your community what it is: its terminology, its acronyms, its slang.

### What kinds of meta topics can I post? ###

Some examples of meta topics:

- What sort of topics should we allow and encourage? Which kinds should we explicitly discourage?

- What kinds of replies are we looking for? What makes a good reply, and what makes a reply out of bounds or off-topic?

- What are our standards for community behavior, beyond what is [defined in the FAQ][2]?

- How can we encourage new members of our community and welcome them?

- Are we setting a good example for the kinds of discussions we want in our community?

- What problems and challenges does our community face, and how can they be resolved?

- How should we moderate our community, and who should the moderators be? What should our flag reasons be?

- How do we publicize and grow our community?

- What does does TLA mean? Who was Kilroy and why does everyone drop his name when they make a typo?

- How should (or why did) the rules change?

But really, anything is fair game in the meta category, provided it's a discussion about the community or the forum in some way.

[1]: http://en.wikipedia.org/wiki/Metaphysics_(Aristotle)
[2]: #{faq_url}
TEXT
  end

  def _admin_guide_raw
    admin_url = admin_url()
    tos_url = tos_url()
    meta_url = category_url(category: "meta")
    email_logs_url = logs_admin_email_index_url
    content_license_url = admin_site_content_url(id: "tos_user_content_license")
    <<TEXT
You are now the proud owner of your very own Civilized Discourse Construction Kit. Congratulations! As a new forum admin admin, here's a quick start guide to get you going:

### Login as an Admin ###

The production seed data for Discourse forums comes with this topic (obviously!) and a pre-built admin account:

> username: `forumadmin`  
> password: `password`

You can login via the blue "Log in" button in the upper-right hand corner of Discourse.

Needless to say, do NOT forget to change the password on that account.

### Access the Admin Console ###

To access the Discourse admin console, add `/admin` to the base URL, like so:

### [/admin](#{admin_url}) ###

From here, you'll be able to access the Admin functions, all of which are very important, so do check them out: site settings, users, email, flags, and customize.

### Enable Twitter Logins ###

1. From the Administrative console above, enter **Site Settings**.
2. Scroll down to the two text fields named:

  `twitter_consumer_key`  
  `twitter_consumer_secret`  

3. Enter in your respective **key** and **secret** that is issued to you via dev.twitter.com. If you are unsure of what your key/secret is, or you have yet to obtain one, visit the Twitter Dev API FAQ on [how to obtain these keys](https://dev.twitter.com/docs/faq#7447).

### Enable Facebook Logins ###

1. From the Administrative console above, enter **Site Settings**.
2. Scroll down to the two text fields named:

  `facebook_app_id`  
  `facebook_app_secret`  

3. Enter in your respective **id** and **secret** that is issued to you via developers.facebook.com. If you are unsure of what your id/secret is, or you have yet to obtain one, visit the [Facebook Developers :: Access Tokens and Types](https://developers.facebook.com/docs/concepts/login/access-tokens-and-types/) page for more information.

### Creating New Categories ###

You will get one new category by default, meta. [Check it out! It's important](#{meta_url}). But you may want more.

Categories are the **colored labels** used to organize groups of topics in Discourse, and they are completely customizable:

1. Log in to Discourse via an account that has Administrative access.
2. Click the "Categories" button in the navigation along the top of the site.
3. You should now see a "Create Category" button.
4. Select a name and set of colors for the category for it in the dialog that pops up.
5. Write a paragraph describing what the category is about in the first post of the Category Definition Topic associated with that category. It'll be pinned to the top of the category, and used in a bunch of places.

### File and Image Uploads ###

Image uploads should work fine out of the box, stored locally, though you can configure it so that images users upload go to Amazon S3.

Discourse currently does not support arbitrary file uploads, but this functionality is being built as we speak and should be available soon. We'll update this guide when it is ([Reference](http://meta.discourse.org/t/file-upload-support/2879/7)).

### Test Email Sending ###

Discourse relies heavily on emails to notify folks about conversations happening on the forum. Visit [the admin email logs](#{email_logs_url}), then enter an email address in the "email address to test" field and click <kbd>send test email</kbd>. Did it work? Great! If not, your users may not be getting any email notifications.

### Set your Terms of Service and User Content Licensing ###

Make sure you set your company name and domain variables for the [Terms of Service](#{tos_url}), which is a creative commons document.

You'll also need to make an important legal decision about the content users post on your forum:

> Your users will always retain copyright on their posts, and will always grant the forum owner enough rights to include their content on the forum.
> 
> Who is allowed to republish the content posted on this forum?
> 
> - Only the author
> - Author and the owner of this forum
> - Anybody

Please see our [admin User Content Licensing](#{content_license_url}) page for a brief form that will let you cut and paste your decision into section #3 of the [Terms of Service](/tos).

### Customize CSS / Header Logos ###

1. Access the Administrative console, and select "Customize".

2. You'll see a list of styles down the left-hand column, and two subcategories: "Stylesheet" and "Header".

  - Insert your custom CSS styles into the "Stylesheet" section.

  - Insert your custom HTML header into the "Header" section.

3. **Enable:** If you wish to have your styles and header take effect on the site, check the "Enable" checkbox, then click "Save". This is also known as "live reloading", which will cause your changes to take effect immediately.

4. **Preview:** If you wish to preview your changes before saving them, click the "preview" link at the bottom of the screen. Your changes will be applied to the site as they are currently saved in the "Customize" panel. If you aren't happy with your changes and wish to revert, simply click the "Undo Preview" link.

5. **Override:** If you wish to have your styles override the default styles on the site, check the "Do not include standard style sheet" checkbox.

Here is some example HTML that would go into the "Header" section within "Customize":

```
<div class='myheader' style='text-align:center;background-color:#CDCDCD'>
<a href="/"><img src="http://dummyimage.com/1111x90/CDCDCD/000000.jpg&text=Placeholder+Custom+Header" width="1111px" height="90px" border="0" /></a>    
</div>
```

### Ruby and Rails Performance Tweaks ###

- Be sure you have at least 1 GB of memory for your Discourse server. You might be able to squeak by with less, but we don't recommend it, unless you are an expert.

- We strongly advise setting `RUBY_GC_MALLOC_LIMIT` to something much higher than the default for optimal performance. See [this meta.discourse topic for more details][1]. 

### Need more Help? ###

This guide is a work in progress and we will be continually improving it with your feedback.

For more assistance on configuring and running your Discourse forum, see [the support category on meta.discourse.org]().

[1]: http://meta.discourse.org/t/tuning-ruby-and-rails-for-discourse/4126
[2]: http://meta.discourse.org/category/support
TEXT
  end

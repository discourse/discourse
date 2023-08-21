Congratulations, you are now the proud owner of your very own [Civilized Discourse Construction Kit](https://www.discourse.org). :hatching_chick:

![](https://www.discourse.org/images/welcome/welcome-to-discourse-hosting-690x314.jpg)

# 1. Initial setup 
Discourse is a powerful, versatile platform with many options.  To help you make sure you're covering all the bases as you get started with your new community, we provided some checklists and guidance below. If you haven't already, [complete the Setup Wizard](/wizard) which covers the essentials. 

You now also need to [test your email](#h-4-maintaining-your-discourse-server-14) to make sure it is configured correctly, otherwise new signups and notifications will not work. 

For more assistance on configuring and running your Discourse forum, see [meta.discourse.org](https://meta.discourse.org/).
 
### Recommended before inviting most of your members
It is essential that you provide a meaningful name and description for your site, so your members immediately know what your community is about. Also edit the welcome topic. In a few sentences, let everyone know who this community is for, what they can expect to find here, and what you'd like them to do as soon as they arrive. 

[] Add your site name and description
[] Edit your welcome topic

### Legal
You are responsible for providing your organization's details and legal notices. Discourse will place boilerplate templates in your #staff category when you add your company name in the setup wizard. 

[] Add your company name and details
[] Edit the boilerplate TOS or provide a link to the TOS on your main site
[] Edit the boilerplate Privacy Notice or provide a link to the Privacy Notice on your main site

### Customization options 

Out of the box, Discourse provides a clean, friendly design. Via the setup wizard and admin dashboard, you can make changes easily to make your site look and feel unique. No special skills are required, but advanced options are available if you have access to the tech skills. 

[] Upload logo images
[] Change the color scheme
[] Change the font used for text and headers
[] Install a different site theme 
[] Choose a different homepage style
[] Customize the default categories and tags shown on the sidebar
[] Add a custom section to the sidebar
[] Add custom user fields to let members provide more info about themselves

[details="Advanced options"]

Discourse is very configurable and there is a great deal programmers and web designers can do to customize it, integrate it into other platforms, or address any use case. Users going down this route are highly encouraged to join meta.discourse.org, our support community, to learn from what others have and to give and get advice. 

[] Add one or more social login options: [Google](https://meta.discourse.org/t/configuring-google-oauth2-login-for-discourse/15858), [Twitter](https://meta.discourse.org/t/configuring-twitter-login-for-discourse/13395), [Facebook](https://meta.discourse.org/t/configuring-facebook-login-for-discourse/13394), [GitHub](https://meta.discourse.org/t/configuring-github-login-for-discourse/13745), [Discord](https://meta.discourse.org/t/configure-discord-login-for-discourse/127129?u=tobiaseigen), [Apple](https://www.discourse.org/plugins/apple-login), [Amazon, LinkedIn, and Microsoft](https://www.discourse.org/plugins/amazon-linkedin-microsoft-login)
[] [Embed Discourse in your WordPress website](https://github.com/discourse/wp-discourse), or [on your static HTML site](https://meta.discourse.org/t/embedding-discourse-comments-via-javascript/31963)
[] Set up [single-sign on](https://meta.discourse.org/t/official-single-sign-on-for-discourse/13045) with your main site 
[] [Build your own login method](https://meta.discourse.org/t/login-to-discourse-with-custom-oauth2-provider/14717)
[] [Create your own theme](https://meta.discourse.org/docs?topic=93648) 
[] [Interact with Discourse from other applications using the API](https://meta.discourse.org/t/create-and-configure-an-api-key/230124?u=tobiaseigen)
[/details]

# 2. Invite your members
Once you've done the initial setup, you're ready to invite your founding members who can help you finish setup and get some conversations started. Go to [your invites page](/my/invited) and look for the <kbd>+ Invite</kbd> button to create invite links you can share or directly email everyone you want to have in your community. **Be sure to follow up to make sure they join and start participating!**

### To complete together with your founding members
[] Founding members sign up and commit to visiting and participating regularly (at least 3 recommended)
[] Members provide their name, bio and picture
[] Create interesting topics (at least 5 topics and 30 replies recommended)
[] Start talking in chat
[] Talk in #feedback about how to use the site and how it is organized
[] Review and edit the provided Community Guidelines (FAQ) 

### When you're ready, launch your community!
[] For public sites, link your community everywhere and promote it so people can find it!
[] Send out invitations by email and by sharing invite links in channels used by your community (you can also create [bulk invites](https://meta.discourse.org/t/sending-bulk-user-invites/16468) and [invite users into groups](https://meta.discourse.org/t/invite-individual-users-to-a-group/15544))
[] Keep following up to make sure as many people as possible are joining and communicating with each other on your Discourse site

> **Note:** To make launching your new site easier, all new members will have daily email summary emails enabled (instead of the usual weekly) and be given a higher level of trust. See below to learn more about the trust system and bootstrap mode.

# 3. Managing your forum

### Admin and Moderator tools 
Exercise your admin superpowers anytime via the [admin dashboard](/admin). You can access it via the :wrench: admin link on the menu. Admin and moderator functions are generally marked with the wrench :wrench: icon, so look for that.

### Staff
Staff members are official representatives of this community. There are two kinds of Staff in Discourse:

1. **Admins**, who can do anything and configure anything on this site.
2. **Moderators**, who can edit all posts and users but cannot add categories or change any site settings.

Promoting members of your community is easy:

- select :wrench: admin wrench on their user page
- look for the <kbd>Grant Admin</kbd> and <kbd>Grant Moderator</kbd> buttons there

### Categories
You have three default categories:

1. [General](/category/general) – create topics here that don't fit into any other existing category.
2. [Site Feedback](/category/site-feedback) – Discussion about this site, its organization, how it works, and how you and your community can improve it. [It's important!](https://meta.discourse.org/t/5249)
3. [Staff](/category/staff) – Visible only to staff (admins and moderators)
**Only create a few initial categories**, as you can overwhelm your community. You can always add more categories later and easily bulk recategorize topics. You and your members will have a better experience if you figure out the organization as you go rather than assuming you'll get it all right from the beginning.

Select the :wrench: admin wrench on the [categories page](https://dev.discourse.org/categories) to add a category. You can set security per-category so only certain groups of users can see topics in that category.

Every category has an initial "About this category" topic which you will want to edit to suit your needs. This topic will be pinned to the top of the category, and the description you enter in the first paragraph will appear throughout. Be sure to give your new category a good, clear description, so people understand what belongs there!

In addition to categories, Discourse allows you to organize topics with tags. Tags offer a flexible alternative to categories. Create tags when editing topics.

### Pinned topics and banners
Note how pinning topics works in Discourse:

- Once someone reads to the bottom of a pinned topic, it is automatically unpinned for them specifically. They can change this via the personal pin controls at the bottom of the topic.
- When staff pins a topic, they can pin it globally to all topic lists, or just within its category.

If a pin isn't visible enough, you can also turn one single topic into a **banner**. The banner topic floats on top of all topics and all primary pages. Users can permanently dismiss this floating banner by clicking the × in the upper right corner.

To make (or remove) a pin or banner, use the topic :wrench: admin wrench.

### Forum moderation and community building
Discourse has a trust level system where users earn trust over time and gain abilities to assist in governing their community. The trust level system is designed to offer safe defaults, even for public communities with no active moderation. You should not have to change them. For more details, see [Understanding Trust Levels](https://blog.discourse.org/2018/06/understanding-discourse-trust-levels/).

> **0 (new) → 1 (basic) → 2 (member) → 3 (regular) → 4 (leader)**

To make launching your new site easier, all new users will have daily email summary emails enabled (instead of the usual weekly) and be given a higher level of trust that allows them to bypass new user restrictions. Once you've reached a certain number of users (adjustable via the [Bootstrap mode admin setting](/admin/site_settings/category/all_results?filter=bootstrap)) new users will have to spend 15 minutes reading to remove new user restrictions, or be invited by another trusted user.

# 4. Maintaining your Discourse server

### Test Your Email

Email is required for new account signups and notifications. **Test your email to make sure it is configured correctly!**  Visit [the admin email settings](/admin/email), then enter an email address in the "email address to test" field and click <kbd>send test email</kbd>.

- You got the test email? Great! **Read that email closely**, it has important email deliverability tips.
- You didn't get the test email? This means your users probably aren't getting any signup or notification emails either.
- Email deliverability can be hard. Read [**Email Service Configuration**](https://github.com/discourse/discourse/blob/main/docs/INSTALL-email.md).

If you'd like to enable *replying* to topics via email, [see this howto](https://meta.discourse.org/t/set-up-reply-via-email-support/14003).

### Maintenance

- One CPU and 1GB of memory, with swap, is the minimum for a basic Discourse community. As your community grows you may need more memory or CPU resources.

- [Our Docker container install](https://github.com/discourse/discourse/blob/main/docs/INSTALL.md) is the only one we officially support. It guarantees easy updates, and all recommended optimizations from the Discourse team.

- You should get an email notification when new versions of Discourse are released. To update your instance via our easy one click upgrade process, visit [/admin/upgrade](/admin/upgrade).

### Optional things you might eventually want to set up
[] [Automatic daily backups](https://meta.discourse.org/t/configure-automatic-backups-for-discourse/14855)
[] [HTTPS support](https://meta.discourse.org/t/allowing-ssl-for-your-discourse-docker-setup/13847)
[] [Content Delivery Network support](https://meta.discourse.org/t/enable-a-cdn-for-your-discourse/14857)
[] [Reply via Email](https://meta.discourse.org/t/set-up-reply-via-email-support/14003)
[] [Import and Export your data](https://meta.discourse.org/t/move-your-discourse-instance-to-a-different-server/15721)
[] [Change the domain name](https://meta.discourse.org/t/how-do-i-change-the-domain-name/16098)
[] [Multiple Discourse instances on the same server](https://meta.discourse.org/t/multisite-configuration-with-docker/14084)
[] [Import old content from vBulletin, PHPbb, Vanilla, Drupal, BBPress, etc](https://github.com/discourse/discourse/tree/main/script/import_scripts)
[] [Configure a firewall on your server](https://meta.discourse.org/t/configure-a-firewall-for-discourse/20584).
[] [A user friendly offline page when rebuilding or upgrading](https://meta.discourse.org/t/adding-an-offline-page-when-rebuilding/45238)

#  Resources and help are a click away
* Read our blog post [Building a Discourse Community](http://blog.discourse.org/2014/08/building-a-discourse-community/) 
* Join meta.discourse.org, our official community, to discuss features, bugs, hosting, development and general support with other Discourse users 
* Search <https://meta.discourse.org/docs> for detailed documentation about using discourse, moderation, the admin dashboard, theming and customization, and much much more. 

----

Have suggestions to improve or update this guide? Submit a [pull request](https://github.com/discourse/discourse/blob/main/docs/ADMIN-QUICK-START-GUIDE.md).

Congratulations, you are now the proud owner of your very own [Civilized Discourse Construction Kit](http://www.discourse.org). :hatching_chick:

### Getting Started

If you haven't already, launch the [setup wizard](/wizard) and go through the steps to configure your site. You can run the wizard as many times as you want, it's completely safe!

### Admin Dashboard

Exercise your admin superpowers any time via the admin dashboard at

[**/admin**](/admin)

You can also access it via the "hamburger" <kbd>☰</kbd> menu in the upper right: Admin functions are generally marked with the wrench :wrench:  icon, so look for that.

### Staff

Staff members are official representatives of this community. There are two kinds of Staff:

1. **Admins**, who can do anything and configure anything on this site.
2. **Moderators**, who can edit all posts and users, but cannot add categories or change any site settings.

To add additional staff members:

- have them sign up on the site (or [send out an invitation to join via your user page](/my/invited))
- click the admin button :wrench: on their user page
- look for the <kbd>Grant Admin</kbd> and <kbd>Grant Moderator</kbd> buttons there

### Social Logins

Users can log in with traditional local username and password accounts. You may want to add:

- [Google logins](https://meta.discourse.org/t/configuring-google-oauth2-login-for-discourse/15858)
- [Twitter logins](https://meta.discourse.org/t/configuring-twitter-login-for-discourse/13395)
- [Facebook logins](https://meta.discourse.org/t/configuring-facebook-login-for-discourse/13394)
- [GitHub logins](https://meta.discourse.org/t/configuring-github-login-for-discourse/13745)

You can also [set up single-sign on](https://meta.discourse.org/t/official-single-sign-on-for-discourse/13045), or even [build your own login method](https://meta.discourse.org/t/login-to-discourse-with-custom-oauth2-provider/14717).

### Test Your Email

Email is required for new account signups and notifications. **Test your email to make sure it is configured correctly!**  Visit [the admin email settings](/admin/email), then enter an email address in the "email address to test" field and click <kbd>send test email</kbd>.

- You got the test email? Great! **Read that email closely**, it has important email deliverability tips.
- You didn't get the test email? This means your users probably aren't getting any signup or notification emails either.
- Email deliverability can be hard. Read [**Email Service Configuration**](https://github.com/discourse/discourse/blob/master/docs/INSTALL-email.md).

If you'd like to enable *replying* to topics via email, [see this howto](https://meta.discourse.org/t/set-up-reply-via-email-support/14003).

### Categories

You have three default categories:

1. [Site Feedback](/category/site-feedback) – general discussion about the site itself. [It's important!](https://meta.discourse.org/t/5249)
2. [Lounge](/category/lounge) – a perk for users at trust level 3 and higher
3. [Staff](/category/staff) – visible only to staff (admins and moderators)

**Don't create too many initial categories**, as you can overwhelm your audience. You can always add more categories, and easily bulk recategorize topics later. It's better to figure out the organization as you go rather than assuming you'll get it all right from the beginning (hint: you won't).

To add a category, visit the [categories page](/categories), then click Create Category at the upper right. You can set security per-category so only certain groups of users can see topics in that category.

Every category has an initial "About this category" topic. This topic will be pinned to the top of the category, and the description you enter will be used in a bunch of places. Be sure to give your new category a good, clear description, so people understand what belongs there!

### Pinned Topics and Banners

Note that pinning topics does work a little differently in Discourse:

- Once someone reads to the bottom of a pinned topic, it is automatically unpinned for them specifically. They can change this via the personal pin controls at the bottom of the topic.
- When staff pins a topic, they can pin it globally to all topic lists, or just within its category.

If a pin isn't visible enough, you can also turn one single topic into a **banner**. The banner topic floats on top of all topics and all primary pages. Users can permanently dismiss this floating banner by clicking the &times; in the upper right corner.

To make (or remove) a pin or a banner, use the admin wrench at the top right or bottom of the topic.

### New User Sandbox and the Trust System

If your discussion area is be open to the public, new visitors will arrive that are initially strangers to the community. Discourse has a [trust system](https://blog.discourse.org/2018/06/understanding-discourse-trust-levels/) where users can, over time, earn the trust of the community and gain abilities to assist in governing their community.

Discourse is designed to offer safe defaults for public communities, even with no active moderation.

> **0 (new) &rarr; 1 (basic) &rarr; 2 (member) &rarr; 3 (regular) &rarr; 4 (leader)**

All new users start out in a sandbox with restrictions for everyone's safety. **Trust level 0 (new) users _cannot_** &hellip;

- post more than 2 hyperlinks
- post any images or file attachments
- send personal messages
- flag posts or topics
- have actual links in the "about me" field of their profile
- @name mention more than 2 users in a post

Every action a user can take is rate limited for safety, and especially so for new users. But don't worry, new users can [transition to trust level 1](https://blog.discourse.org/2018/06/understanding-discourse-trust-levels/) in about 10 minutes of reading.

These defaults are safe, but note that while in "bootstrap mode" after you set up your site, all new users will be granted trust level 1 until you reach 50 users.

### Building Your Community

Be patient; building communities is hard. Before launching, be sure to:

1. Clearly define your community's purpose in a pinned or banner topic.
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

- [Our Docker container install](https://github.com/discourse/discourse/blob/master/docs/INSTALL.md) is the only one we officially support. It guarantees easy updates, and all recommended optimizations from the Discourse team.

- You should get an email notification when new versions of Discourse are released. To update your instance via our easy one click upgrade process, visit [/admin/upgrade](/admin/upgrade).

- Some other things you might eventually want to set up:
   - [Automatic daily backups](https://meta.discourse.org/t/configure-automatic-backups-for-discourse/14855)
   - [HTTPS support](https://meta.discourse.org/t/allowing-ssl-for-your-discourse-docker-setup/13847)
   - [Content Delivery Network support](https://meta.discourse.org/t/enable-a-cdn-for-your-discourse/14857)
   - [Reply via Email](https://meta.discourse.org/t/set-up-reply-via-email-support/14003)
   - [Import and Export your data](https://meta.discourse.org/t/move-your-discourse-instance-to-a-different-server/15721)
   - [Change the domain name](https://meta.discourse.org/t/how-do-i-change-the-domain-name/16098)
   - [Multiple Discourse instances on the same server](https://meta.discourse.org/t/multisite-configuration-with-docker/14084)
   - [Import old content from vBulletin, PHPbb, Vanilla, Drupal, BBPress, etc](https://github.com/discourse/discourse/tree/master/script/import_scripts)
   - A firewall on your server? [Configure firewall](https://meta.discourse.org/t/configure-a-firewall-for-discourse/20584).
   - A user friendly [offline page when rebuilding or upgrading?](https://meta.discourse.org/t/adding-an-offline-page-when-rebuilding/45238)
   - Embed Discourse [in your WordPress install](https://github.com/discourse/wp-discourse), or [on your static HTML site](http://eviltrout.com/2014/01/22/embedding-discourse.html)

### Need more Help?

For more assistance on configuring and running your Discourse forum, see [meta.discourse.org](http://meta.discourse.org).

----

Have suggestions to improve or update this guide? Submit a [pull request](https://github.com/discourse/discourse/blob/master/docs/ADMIN-QUICK-START-GUIDE.md).

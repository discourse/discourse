## App Setup

Acting like a Mailing list is disabled per default in Discourse. This guide shows you through the way to enable and configure it.

## Admin UI Setup

First of, you need a POP3s enabled server receiving your email. Then make sure to enable "reply_by_email_enabled" and configured the server appropriately in your Admin-Settings under "Email":
![enable-reply-by-email](https://f.cloud.github.com/assets/2879972/2242953/97d5dd52-9d17-11e3-915e-037758cc68a7.png)

Once that is in place, you can enable the "email_in"-feature globally in the same email-section. If you provide another "email_in_address" all emails arriving in the inbox to that address will be handeled and posted to the "email_in_category" (defaults to "uncategorised"). For spam protection only users of a high trust level can post via email per default. You can change this via the "email_in_min_trust" setting.

### Per category email address

Once "email_in" is enabled globally a new configuration option appears in your category settings dialog allowing you to specify an email-address for that category. Emails going to the previously configured inbox to that email-address will be posted in this category instead of the default configuration. **Attention** User-Permissions and the minimum trust levels still apply.

Additionally, by checking the "accept non-user emails"-checkbox in the category settings, emails to the given email but from unknown email-addresses will be posted in the category by the System-User in a quoted fashion, showing the original email-address and content in the quotes.

### Troubleshooting

You might want to allow users to opt-in to receive all posts via email with the option on the bottom:
![enable-mailing-list-mode](https://f.cloud.github.com/assets/2879972/2242954/994ac2a6-9d17-11e3-8f1f-31e570905394.png)

As there is no way to enforce subject lines, you might want to lower minimum topic length, too
![lower-min-topic-length](https://f.cloud.github.com/assets/2879972/2242956/9b20df84-9d17-11e3-917b-d91c17fd88c3.png)

And as some emails may have the same subject, allow duplicate titles might be another option you want to look at
![allow-duplicate-titles](https://f.cloud.github.com/assets/2879972/2242957/9ce3ed70-9d17-11e3-88ae-b7f9b63145bf.png)

## Suggested User Preferences
![suggested-user-prefs](https://f.cloud.github.com/assets/2879972/2242958/9e866356-9d17-11e3-815d-164c78794b01.png)


## FAQ

**Q: Why is this needed?**

 >A: No matter how good a forum is, sometimes members need to ask a question and all they have is their mail client.


**Q: What if a message is received from an email address which doesn't belong to an approved, registered user?**

 >A: It will be rejected, and a notification email sent to the moderator. Check your POP mailbox to see the rejected email content.


**Q: Who did this?** 

 >A: @therealx, @yesthatallen and @ligthyear


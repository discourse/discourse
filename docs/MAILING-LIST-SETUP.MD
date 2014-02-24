## App Setup
> TODO build an admin UI for this, get it out of discourse_defaults.conf

Enable new topic creation via email by setting this value to "true"
`allow_new_topics_from_email = `

Set the default category for new threads by entering the category number here
`default_categories_id = `


## Admin UI Setup

Let's tell discourse to check for emails
![enable-reply-by-email](https://f.cloud.github.com/assets/2879972/2242953/97d5dd52-9d17-11e3-915e-037758cc68a7.png)
Be sure to setup email as you would for POP3 based replies.

If users will be using discourse as a mailing list, allow them to opt-in
![enable-mailing-list-mode](https://f.cloud.github.com/assets/2879972/2242954/994ac2a6-9d17-11e3-8f1f-31e570905394.png)
#TODO Document how to set this true by default

No way to enforce subject lines, so lower minimum topic length
![lower-min-topic-length](https://f.cloud.github.com/assets/2879972/2242956/9b20df84-9d17-11e3-917b-d91c17fd88c3.png)

Emails may have the same subject, allow duplicate titles
![allow-duplicate-titles](https://f.cloud.github.com/assets/2879972/2242957/9ce3ed70-9d17-11e3-88ae-b7f9b63145bf.png)

## Suggested User Preferences
![suggested-user-prefs](https://f.cloud.github.com/assets/2879972/2242958/9e866356-9d17-11e3-815d-164c78794b01.png)


## FAQ

Q: Why is this needed?

A: No matter how good a forum is, sometimes members need to ask a question and all they have is their mail client.


Q: What if a message is received from an email address which doesn't belong to an approved, registered user?

A: It will be rejected, and a notification email sent to the moderator. Check your POP mailbox to see the rejected email content.




Q: Who did this?  

A: @therealx and @yesthatallen


### Recommended Email Providers for Discourse

We strongly recommend using a dedicated email service. Email server setup and maintenance is _very_ difficult even for experienced system administrators, and getting any part of the complex required email setup wrong means your email won't be delivered, or worse, delivered erratically.

The following are template configurations for email service providers who offer generous free plans that work for most communities.

**Please note that in any email provider, you _must_ verify and use the subdomain, e.g. `discourse.example.com`. If you verify the domain only, e.g. `example.com`, mail will not be configured correctly.**

Enter these values when prompted by `./discourse-setup` per the [install guide](https://github.com/discourse/discourse/blob/master/docs/INSTALL-cloud.md#edit-discourse-configuration):

#### [Mailgun][gun] &mdash; 10k emails/month (with credit card)

    SMTP server address? smtp.mailgun.org
    SMTP user name?      [SMTP credentials for your domain under domains tab]
    SMTP password?       [SMTP credentials for your domain under domains tab]

#### [Elastic Email][ee] &mdash; 150k emails/month (5k max/day)

    SMTP server address? smtp.elasticemail.com
    SMTP user name?      [Your registered email address]
    SMTP password?       [Elastic Email API Key]
    SMTP port?           2525

NOTE: Elastic Email currently doesn't fully integrate with Discourse's internal unsubscribe mechanism and hence puts an additional UNSUBSCRIBE link at the bottom of each sent email. If this is a problem for your needs, consider using other providers. [See discussion here](https://meta.discourse.org/t/remove-or-merge-elastic-email-unsubscribe/70236).

#### [SendGrid][sg] &mdash; 40k emails on a 30 day trial

    SMTP server address? smtp.sendgrid.net
    SMTP user name?      apikey
    SMTP password?       [SendGrid API Key]

We recommend creating an [API Key][sg2] instead of using your SendGrid username and password.

#### [Mailjet][jet] &mdash; 6k emails/month

Go to [My Account page](https://www.mailjet.com/account) and click on the ["SMTP and SEND API Settings"](https://www.mailjet.com/account/setup) link.

   [ee]: https://elasticemail.com
  [jet]: https://www.mailjet.com/pricing
  [gun]: http://www.mailgun.com/
   [sg]: https://sendgrid.com/
  [sg2]: https://sendgrid.com/docs/Classroom/Send/How_Emails_Are_Sent/api_keys.html

### Bounce Handling

When using a third party email service, you will need to enable VERP, or activate their **webhooks** in order to handle bouncing emails. [Full details here.](https://meta.discourse.org/t/handling-bouncing-e-mails/45343)

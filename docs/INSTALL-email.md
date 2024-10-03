### Recommended Email Providers for Discourse

We strongly recommend using a dedicated email service. Email server setup and maintenance is _very_ difficult even for experienced system administrators, and getting any part of the complex required email setup wrong means your email won't be delivered, or worse, delivered erratically.

The following are template configurations for email service providers known to work with Discourse.

_The pricing information is included as a courtesy, and may be out of date. Discourse does not control the pricing for external services, be sure to check with the email provider for up to date pricing information._

**Please note that in any email provider, you _must_ verify and use the subdomain, e.g. `discourse.example.com`. If you verify the domain only, e.g. `example.com`, mail will not be configured correctly.**

Enter these values when prompted by `./discourse-setup` per the [install guide](https://github.com/discourse/discourse/blob/main/docs/INSTALL-cloud.md#edit-discourse-configuration). To change the current email service, run `./discourse-setup` as well (this will bring the forum offline for a few minutes while it gets rebuilt).

#### [Brevo, previously SendInBlue, GDPR][sb] &mdash; 300 email per day free

    SMTP server address? smtp-relay.brevo.com
    SMTP user name?      [SMTP credentials for your domain under [SMTP-Key tab](https://app.brevo.com/settings/keys/smtp)]
    SMTP password?       [SMTP credentials for your domain under [SMTP-Key tab](https://app.brevo.com/settings/keys/smtp)]
    Port:                587
    
#### [Mailgun][gun] &mdash; 5k emails/month on a 3 month trial

    SMTP server address? smtp.mailgun.org
    SMTP user name?      [SMTP credentials for your domain under domains tab]
    SMTP password?       [SMTP credentials for your domain under domains tab]

#### [SendGrid][sg] &mdash; 40k emails on a 30 day trial

    SMTP server address? smtp.sendgrid.net
    SMTP user name?      apikey
    SMTP password?       [SendGrid API Key]

We recommend creating an [API Key][sg2] instead of using your SendGrid username and password.

#### [Mailjet][jet] &mdash; 6k emails/month (200 max/day)

Go to [My Account page](https://app.mailjet.com/account) and click on the ["SMTP and SEND API Settings"](https://app.mailjet.com/account/relay) link to generate a secret key and get the SMTP server address.

    SMTP server address? [Mailjet SMTP server address]
    SMTP username?       [Mailjet API key]
    SMTP password?       [Mailjet secret key]

#### [Elastic Email][ee]

    SMTP server address? smtp.elasticemail.com
    SMTP user name?      [Your registered email address]
    SMTP password?       [Elastic Email API Key]
    SMTP port?           2525
    
NOTE: By default, Elastic Email will add an additional UNSUBSCRIBE link at the bottom of each sent email. You need to work with them to [disable that link](https://meta.discourse.org/t/remove-or-merge-elastic-email-unsubscribe/70236/39), so that Discourse users can manage their subscription through Discourse.

   [ee]: https://elasticemail.com
  [jet]: https://www.mailjet.com/pricing
  [gun]: https://www.mailgun.com/
   [sb]: https://www.brevo.com/products/transactional-email/
   [sg]: https://sendgrid.com/
  [sg2]: https://sendgrid.com/docs/Classroom/Send/How_Emails_Are_Sent/api_keys.html
  

### Bounce Handling

When using a third party email service, you will need to enable VERP, or activate their **webhooks** in order to handle bouncing emails. [Full details here.](https://meta.discourse.org/t/handling-bouncing-e-mails/45343)

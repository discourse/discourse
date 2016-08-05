### Recommended Email Providers for Discourse

We strongly recommend using a dedicated email service. Email server setup and maintenance is _very_ difficult even for experienced system administrators, and getting any part of the complex required email setup wrong means your email won't be delivered, or worse, delivered erratically.

The following are template configurations for email service providers who offer generous free plans that work for most communities.

**Please note that in any email provider, you _must_ verify and use the subdomain, e.g. `discourse.example.com`. If you verify the domain only, e.g. `example.com`, mail will not be configured correctly.**

Enter these values when prompted by `./discourse-setup` per the [install guide](https://github.com/discourse/discourse/blob/master/docs/INSTALL-cloud.md#edit-discourse-configuration):

#### [SparkPost][sp] &mdash; 100k emails/month

    SMTP server address? smtp.sparkpostmail.com
    SMTP user name?      SMTP_Injection
    SMTP password?       [Any API key with Send via SMTP permission]

#### [SendGrid][sg] &mdash; 12k emails/month

    SMTP server address? smtp.sendgrid.net
    SMTP user name?      apikey
    SMTP password?       [SendGrid API Key]

We recommend creating an [API Key][sg2] instead of using your SendGrid username and password.

#### [Mailgun][gun] &mdash; 10k emails/month

    SMTP server address? smtp.mailgun.org
    SMTP user name?      [SMTP credentials for your domain under domains tab]
    SMTP password?       [SMTP credentials for your domain under domains tab]

#### [Mailjet][jet] &mdash; 6k emails/month

Go to [My Account page](https://www.mailjet.com/account) and click on the ["SMTP and SEND API Settings"](https://www.mailjet.com/account/setup) link.

   [sp]: https://www.sparkpost.com/
  [jet]: https://www.mailjet.com/pricing
  [gun]: http://www.mailgun.com/
   [sg]: https://sendgrid.com/
  [sg2]: https://sendgrid.com/docs/Classroom/Send/How_Emails_Are_Sent/api_keys.html

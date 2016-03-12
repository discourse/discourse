## Recommended Email Providers for Discourse

We strongly recommend using a dedicated email service. Email server setup and maintenance is _very_ difficult even for experienced system administrators, and getting any part of the complex required email setup wrong means your email won't be delivered, or worse, delivered erratically.

The following are template configurations for email service providers who offer generous free plans that work for most communities.

Use these values when you [edit your Discourse `app.yml` configuration file](https://github.com/discourse/discourse/blob/master/docs/INSTALL-cloud.md#edit-discourse-configuration):

#### [SparkPost][sp] (100k emails/month)

```yml
DISCOURSE_SMTP_ADDRESS: smtp.sparkpostmail.com
DISCOURSE_SMTP_PORT: 587
DISCOURSE_SMTP_USER_NAME: SMTP_Injection
DISCOURSE_SMTP_PASSWORD: [Any API key with Send via SMTP permission]
```

#### [SendGrid][sg] (12k emails/month)

```yml
DISCOURSE_SMTP_ADDRESS: smtp.sendgrid.net
DISCOURSE_SMTP_PORT: 587
DISCOURSE_SMTP_USER_NAME: [SendGrid username]
DISCOURSE_SMTP_PASSWORD: [SendGrid password]
```

#### [Mailgun][gun] (10k emails/month)


```yml
DISCOURSE_SMTP_ADDRESS: smtp.mailgun.org
DISCOURSE_SMTP_PORT: 587
DISCOURSE_SMTP_USER_NAME: [SMTP credentials for your domain under Mailgun domains tab]
DISCOURSE_SMTP_PASSWORD: [SMTP credentials for your domain under Mailgun domains tab]
```

#### [Mailjet][jet] (6k emails/month)

Go to [My Account page](https://www.mailjet.com/account) and click on the ["SMTP and SEND API Settings"](https://www.mailjet.com/account/setup) link.


   [sp]: https://www.sparkpost.com/
  [jet]: https://www.mailjet.com/pricing
  [gun]: http://www.mailgun.com/
   [sg]: https://sendgrid.com/

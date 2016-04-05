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

If not using **the exact** domain you verified (e.g. you're using a subdomain of it), you must change the default `from` email to match the sending domain. Uncomment (and update with your sending domain) this line in `app.yml`:

```yml
- exec: rails r "SiteSetting.notification_email='info@unconfigured.discourse.org'"
```

#### [SendGrid][sg] (12k emails/month)

```yml
DISCOURSE_SMTP_ADDRESS: smtp.sendgrid.net
DISCOURSE_SMTP_PORT: 587
DISCOURSE_SMTP_USER_NAME: apikey
DISCOURSE_SMTP_PASSWORD: [SendGrid API Key]
```
We recommend creating an [API Key][sg2] instead of using your SendGrid username and password.

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
  [sg2]: https://sendgrid.com/docs/Classroom/Send/How_Emails_Are_Sent/api_keys.html

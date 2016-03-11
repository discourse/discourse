## Email Is Important

We strongly recommend using dedicated email services.

The following are template configurations for email service providers who offer generous free plans that work for most communities.

Use these values when you [edit the Discourse configuration](https://github.com/discourse/discourse/blob/master/docs/INSTALL-cloud.md#edit-discourse-configuration) (`app.yml`). Replace the bracketed values with your values from the service.

#### [SparkPost][sp] configuration (100k emails/month)

```yml
DISCOURSE_SMTP_ADDRESS: smtp.sparkpostmail.com
DISCOURSE_SMTP_PORT: 587
DISCOURSE_SMTP_USER_NAME: SMTP_Injection
DISCOURSE_SMTP_PASSWORD: [Any API key with Send via SMTP permission]
```

#### [SendGrid][sg] configuration (12k emails/month)

```yml
DISCOURSE_SMTP_ADDRESS: smtp.sendgrid.net
DISCOURSE_SMTP_PORT: 587
DISCOURSE_SMTP_USER_NAME: [SendGrid username]
DISCOURSE_SMTP_PASSWORD: [SendGrid password]
```

#### [Mailgun][gun] configuration (10k emails/month)


```yml
DISCOURSE_SMTP_ADDRESS: smtp.mailgun.org
DISCOURSE_SMTP_PORT: 587
DISCOURSE_SMTP_USER_NAME: [SMTP credentials for your domain under Mailgun domains tab]
DISCOURSE_SMTP_PASSWORD: [SMTP credentials for your domain under Mailgun domains tab]
```

#### [Mailjet][jet] configuration (6k emails/month)

Go to [My Account page](https://www.mailjet.com/account) and click on the ["SMTP and SEND API Settings"](https://www.mailjet.com/account/setup) link.


   [sp]: https://www.sparkpost.com/
  [jet]: https://www.mailjet.com/pricing
  [gun]: http://www.mailgun.com/
   [sg]: https://sendgrid.com/

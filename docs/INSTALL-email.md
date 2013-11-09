# Discourse Mail Setup Guide

After following INSTALL-ubuntu.md your mailer settings should still be set (in
`config/environments/production.rb`, remember) to:

```ruby
  config.action_mailer.delivery_method = :sendmail
  config.action_mailer.sendmail_settings = {arguments: '-i'}
```

That's great. Leave that there as we're going to try to get the mail to postfix
ASAP so postfix do it's job and process the mail for delivery.

## Email is IMPORTANT

Email notifications are core to the Discourse experience. We want your users to receive notifications as soon as possible so they can contribute to the conversation.

If sending email isn't something to which you want to devote your time, don't
worry about it. There are [companies](http://mandrill.com/) that dedicate
theirs to doing one thing very well - ensuring that mail to your users gets
delivered.

## Sending Email Through GMail

Don't do it! GMail is not intended for sending out bulk notifications. Your email setup [will break](http://webapps.stackexchange.com/q/44768/12456).

## Sending Email Through Mandrill

### Create an account
We're going to use [Mandrill](http://mandrill.com/) as our email delivery
provider.

![mandrill email signup](https://raw.github.com/discourse/discourse-docimages/master/email/email%20-%20mandrill%20signup.png)

1. Create an account at http://mandrill.com/ (click on 'SIGN UP')

1. I filled out the 'Tell Us A Little About Yourself' survey. They are
providing us a free service, after all!

### Create an API key
I'm pleased with Mandrill's setup - this is the Right Way to do things.

![mandrill email signup](https://raw.github.com/discourse/discourse-docimages/master/email/email%20-%20mandrill%20getsmtpcreds.png)

1. Click 'Get SMTP Credentials'

![mandrill email signup](https://raw.github.com/discourse/discourse-docimages/master/email/email%20-%20mandrill%20addapikey.png)

1. Note that you can use 'any valid API key' as your password. Click '+ Add API Key' to create one.

![mandrill email signup](https://raw.github.com/discourse/discourse-docimages/master/email/email%20-%20mandrill%20editapikey1.png)

1. Click 'Edit' to document for what we'll be using this key.

![mandrill email signup](https://raw.github.com/discourse/discourse-docimages/master/email/email%20-%20mandrill%20editapikey2.png)

1. Since we'll only be using this key for sending email and *nothing else*, check 'Only Allow This Key To Use Certain API Calls' and select only Messages / Send and Messages/ Send-Raw. Send-Raw must be selected or Discourse won't be able to send email.
 

![mandrill email signup](https://raw.github.com/discourse/discourse-docimages/master/email/email%20-%20mandrill%20editapikey3.png)

1. Optionally, restrict this key to the public static IP address of your server.

1. Click 'Save'

### Configure Postfix for Mandrill

Thank you Mandrill for providing an excellent [guide on configuring Postfix to use Mandrill](http://help.mandrill.com/entries/23060367-Can-I-configure-Postfix-to-send-through-Mandrill-).

Additional notes on this document:

* Ubuntu has an `/etc/postfix/sasl` directory. Create a password file in there.

* Make sure you put your **API KEY** into this password file, not your **ACCOUNT PASSWORD**

* You may already have configured a `relayhost` earlier in the installation. If this machine is sending out ANY emails other than Discourse-generated notifications, follow the instructions in 'Relay only certain emails through Mandrill'.

After configuring postfix as per Mandrill's instructions, reload postfix with `sudo postfix reload`.

### Send test email

![discourse admin setting](https://raw.github.com/discourse/discourse-docimages/master/email/email%20-%20discourse%20admin.png)

Now we send a test email. Login to your Discourse installation and click on the ≡ (aka congruence/hamburger/etc), then 'Admin'.

![discourse admin setting](https://raw.github.com/discourse/discourse-docimages/master/email/email%20-%20discourse%20emailtest.png)

Click on `Email`, `Settings`, then type your email address into the test box and click `send test email`.

Within moments, you should have email in your Inbox.

### OH NOES I DIDN'T GET MY EMAIL TEST!

Follow the trail. First of all, did the email get to Postfix? Check `/var/log/mail.log`:

    Jun 24 01:24:59 discoursetest postfix/pickup[25387]: 7CBF280294C: uid=1001 from=<info@discourse.org>
    Jun 24 01:24:59 discoursetest postfix/cleanup[25829]: 7CBF280294C: message-id=<51c7d82b6f878_8ef3d7802c10139@discoursetest.mail>
    Jun 24 01:24:59 discoursetest postfix/qmgr[25386]: 7CBF280294C: from=<info@discourse.org>, size=5884, nrcpt=1 (queue active)

Looks good! Wait, why is the email coming *from* `info@discourse.org`? That's a
problem we'll fix below.

    Jun 24 01:25:04 discoursetest postfix/smtp[25831]: 7CBF280294C: SASL authentication failed; server smtp.mandrillapp.com[54.235.146.179] said: 435 4.7.8 Error: authentication failed: 
    Jun 24 01:25:10 discoursetest postfix/smtp[25831]: 7CBF280294C: SASL authentication failed; server smtp.mandrillapp.com[54.234.14.176] said: 435 4.7.8 Error: authentication failed: 
    Jun 24 01:25:13 discoursetest postfix/smtp[25831]: 7CBF280294C: SASL authentication failed; server smtp.mandrillapp.com[50.16.10.62] said: 435 4.7.8 Error: authentication failed: 
    Jun 24 01:25:20 discoursetest postfix/smtp[25831]: 7CBF280294C: to=<spoonman@discourse.org>, relay=smtp.mandrillapp.com[54.235.146.152]:25, delay=21, delays=0.07/0.01/21/0, dsn=4.7.8, status=deferred (SASL authentication failed; server smtp.mandrillapp.com[54.235.146.152] said: 435 4.7.8 Error: authentication failed: )

The above errors are caused by using an incorrect API key in your sasl passwords file. Fix that (edit `/etc/postfix/sasl/passwd`, run `sudo postmap` on it, then `postqueue -f` to restart the queue).

    Jun 24 01:30:30 discoursetest postfix/smtp[25861]: table hash:/etc/postfix/sasl/passwd(0,lock|fold_fix) has changed -- restarting
    Jun 24 01:30:31 discoursetest postfix/smtp[25872]: 7CBF280294C: to=<spoonman@discourse.org>, relay=smtp.mandrillapp.com[54.234.14.176]:25, delay=332, delays=331/0.01/1.2/0.17, dsn=2.0.0, status=sent (250 2.0.0 Ok: queued as C515B6380D3)

That's better! Our test message made it to Mandrill. Let's check Outbound Activity in Mandrill:


![mandrill email confirmation](https://raw.github.com/discourse/discourse-docimages/master/email/email%20-%20mandrill%20emailconfirm.png)

If you see this, the email was accepted by Mandrill and delivered to the
destination. You need to check your spam filter now.

If you don't see anything in Mandrill, ensure that the API key is enabled for
'Send-Raw' permission. Mandrill appears to silently drop the email if that's
not set.

### Configure notification email addresses

Login to Discourse, go to the Admin page and select 'Settings'.

Filter with the string 'system'.

* Ensure that `site_contact_username` is set to an email address for an appropriate "owner" of the forum
* Set `notification_email` to 'noreply@', 'nobody@' as appropriate.

Filter with the string 'contact_email'

* Ensure `contact_email` is set appropriately.

### SPF and DKIM records

Login to Mandrill and click on ⚙ (Settings)-> Sending Domains

If your domain isn't listed, add it. It'll probably show this:

![mandrill missing dkim settings](https://raw.github.com/discourse/discourse-docimages/master/email/email%20-%20mandrill%20missingdkim.png)

Click 'View DKIM/SPF setup instructions'.

Follow the instructions there.

When DNS is properly configured, you should be able to click on 'Test DNS Settings' and Mandrill will confirm they are setup properly:

![mandrill good dkim settings](https://raw.github.com/discourse/discourse-docimages/master/email/email%20-%20mandrill%20gooddkim.png)

### Mandrill Options

Login to Mandrill and click on ⚙ (Settings)-> Sending Options

* 'Track Clicks' is enabled by default. This rewrites links in email messages to bounce off the mandrillapp.com domain for click tracking. Disable it here if you don't want that:

![mandrill rewriting emails](https://raw.github.com/discourse/discourse-docimages/master/email/email%20-%20mandrill%20rewriting.png)

* If you do use it, setting up a 'Tracking Domain' is a very good idea to avoid erroneous scam warnings:

![mandrill tbird warning](https://raw.github.com/discourse/discourse-docimages/master/email/email%20-%20mandrill%20tbirdwarning.png)

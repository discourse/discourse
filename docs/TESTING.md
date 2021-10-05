# Discourse Developer Testing Guide

Some notes about testing Discourse:

## MailHog

Discourse depends heavily on (sending) email for notifications. We use [MailHog](https://github.com/mailhog/MailHog)
to test emails. It's super convenient!

> MailHog runs a super simple SMTP server which catches any message sent to it to display in a web interface. Run mailhog, set your favourite app to deliver to smtp://127.0.0.1:1025 instead of your default SMTP server, then check out http://127.0.0.1:8025 to see the mail that's arrived so far.

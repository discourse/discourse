# Discourse Developer Testing Guide

Some notes about testing Discourse:

## MailCatcher

Discourse depends heavily on (sending) email for notifications. We use [MailCatcher](http://mailcatcher.me/) 
to test emails. It's super convenient!

> MailCatcher runs a super simple SMTP server which catches any message sent to it to display in a web interface. Run mailcatcher, set your favourite app to deliver to smtp://127.0.0.1:1025 instead of your default SMTP server, then check out http://127.0.0.1:1080 to see the mail that's arrived so far.

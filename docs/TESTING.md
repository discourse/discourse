# Discourse Developer Testing Guide

Some notes about testing Discourse:

## FakeWeb

We use the [FakeWeb](https://github.com/chrisk/fakeweb) gem to fake external web 
requests.
For example, check out the specs on `specs/components/oneboxer`.

This has several advantages to making real requests:

* We freeze the expected response from the remote server.
* We don't need a network connection to run the specs.
* It's faster.

So, if you need to define a spec that makes a web request, you'll have to record 
the real response to a fixture file, and tell FakeWeb to respond with it for the 
URI of your request.

Check out `spec/components/oneboxer/amazon_onebox_spec.rb` for an example on 
this.

### Recording responses

To record the actual response from the remote server, you can use curl and save the response to a file. We use the `-i` option to include headers in the output

    curl -i http://en.m.wikipedia.org/wiki/Ruby > wikipedia.response

If you need to specify the User-Agent to send to the server, you can use `-A`:

    curl -i -A 'Mozilla/5.0 (iPhone; CPU iPhone OS 5_0_1 like Mac OS X) AppleWebKit/534.46 (KHTML, like Gecko) Version/5.1 Mobile/9A405 Safari/7534.48.3' http://en.m.wikipedia.org/wiki/Ruby > wikipedia.response 
    
If the remote server is responding with a redirect, you'll need to fake both the 
original request and the one for the destination. Check out the 
`wikipedia.response` and `wikipedia_redirected.response` files in 
`spec/fixtures/oneboxer` for an example. You can also consider working directly 
with the final URL for simplicity.


## MailCatcher

Discourse depends heavily on (sending) email for notifications. We use [MailCatcher](http://mailcatcher.me/) 
to test emails. It's super convenient!

> MailCatcher runs a super simple SMTP server which catches any message sent to it to display in a web interface. Run mailcatcher, set your favourite app to deliver to smtp://127.0.0.1:1025 instead of your default SMTP server, then check out http://127.0.0.1:1080 to see the mail that's arrived so far.

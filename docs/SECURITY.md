##Discourse Security Guide

The following guide covers security regarding your Discourse installation

###Password Storage

Discourse uses the PBKDF2 algorithm to encrypt salted passwords. This algorithm is blessed by NIST. There is an in-depth discussion about its merits in http://security.stackexchange.com/questions/4781/do-any-security-experts-recommend-bcrypt-for-password-storage.

**options you can customise in your production.rb file**

pbkdf2_algorithm: the hashing algorithm used (default "sha256")
pbkdf2_iterations: the number of iterations to run (default is: 64000)


### XSS

The main vector for XSS attacks is via the "composer", as we allow users to generate rather rich markdown we need to protect against poison markdown.

For the composer there are 2 main scenarios we protect against:

1. Markdown preview invokes an XSS. This is severe cause an admin may edit a user's post and a malicious user may then run JavaScript in the context of an admin.

2. Markdown displayed on the page invokes an XSS.

To protect against client side "preview" XSS, Discourse uses Google Caja https://code.google.com/p/google-caja/ in the preview window.

On the server side we run a whitelist based sanitizer, implemented using the Sanitize gem https://github.com/rgrove/sanitize see: https://github.com/discourse/discourse/blob/master/lib/pretty_text.rb

In addition, titles and all other places where non-admins can enter code is protected either using the Handlebars library or standard Rails XSS protection.

### CSRF

CSRF allows malicious sites to perform HTTP requests pretending to be an end-user (without their knowledge) more at: http://en.wikipedia.org/wiki/Cross-site_request_forgery

Discourse extends the built-in Rails CSRF protection in a couple of ways:

1. By default any non GET requests ALWAYS require a valid CSRF token. If a CSRF token is missing Discourse will raise an exception.

2. API calls using the secret API bypass CSRF checks

3. Certain pages are "cachable", we do not render the CSRF token (`<meta name='csrf-token' ...`) on any cachable pages. Instead when user's are about to perform the first non GET request they retrieve the token via GET `session/csrf`

###Deployment concerns

Discourse strongly recommend that the various Discourse processes (web server, clockwork, sidekiq) run under a non-elevated account. See our install guide for details.

###Where should I report security issues?

In order to give the community time to respond and upgrade we strongly urge you report all security issues privately. Please email us at `info@discourse.org` with details and we will respond ASAP.

Security issues ALWAYS take precedence over bug fixes and feature work.


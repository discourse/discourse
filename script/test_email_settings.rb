#!/usr/bin/env ruby
# frozen_string_literal: true

require 'action_mailer'

# Make this your email address. Poor example.com gets SO MUCH MAIL
YOUR_EMAIL = "nobody@example.com"

# Change these to be the same settings as your Discourse environment
DISCOURSE_SMTP_ADDRESS = "smtp.example.com"       # (mandatory)
@DISCOURSE_SMTP_PORT = 587                    # (optional)
@DISCOURSE_SMTP_USER_NAME = "username"              # (optional)
@DISCOURSE_SMTP_PASSWORD  = "blah"                  # (optional)
#@DISCOURSE_SMTP_OPENSSL_VERIFY_MODE = "none"       # (optional) none|peer|client_once|fail_if_no_peer_cert

# Note that DISCOURSE_SMTP_ADDRESS should NOT BE ALLOWED to relay mail to
# YOUR_EMAIL without authentication
MAILFROM = @DISCOURSE_SMTP_USER_NAME || YOUR_EMAIL
MAILTO = YOUR_EMAIL

### You shouldn't need to change anything below here
$delivery_options = {
  user_name: @DISCOURSE_SMTP_USER_NAME || nil,
  password: @DISCOURSE_SMTP_PASSWORD || nil,
  address: DISCOURSE_SMTP_ADDRESS,
  port: @DISCOURSE_SMTP_PORT || nil,
  openssl_verify_mode: @DISCOURSE_SMTP_OPENSSL_VERIFY_MODE || nil
}

class EmailTestMailer < ActionMailer::Base
  def email_test(mailfrom, mailto)
    mail(from: mailfrom,
         to: mailto,
         body: "Testing email settings",
         subject: "Discourse email settings test",
         delivery_method_options: $delivery_options)
  end
end

message = EmailTestMailer.email_test(MAILFROM, MAILTO)

begin
  message.deliver_now()
rescue SocketError => e
  print "Delivery failed: " + e.message.strip() + "\n"
  print " Is the server hostname correct?\n"
rescue OpenSSL::SSL::SSLError => e
  print "Delivery failed: " + e.message.strip() + "\n"
  print " You probably need to change the ssl verify mode.\n"
rescue Net::SMTPAuthenticationError => e
  print "Delivery failed: " + e.message.strip() + "\n"
  print " Check to ensure your username and password are correct.\n"
rescue Net::SMTPFatalError => e
  print "Delivery failed: " + e.message.strip() + "\n"
  print " Check the above error and fix your settings.\n"
else
  print "Successfully delivered.\n"
end

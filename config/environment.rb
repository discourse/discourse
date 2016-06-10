# Load the rails application
require File.expand_path('../application', __FILE__)

# Initialize the rails application
Discourse::Application.initialize!

# When in "dev" mode, ensure we won't be sending any emails
if Rails.env.development? && ActionMailer::Base.smtp_settings != { address: "localhost", port: 1025 }
  fail "In development mode, you should be using mailcatcher otherwise you might end up sending thousands of digest emails"
end

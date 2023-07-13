# frozen_string_literal: true

# Load the Rails application.
require_relative "application"

# Initialize the Rails application.
Rails.application.initialize!

# When in "dev" mode, ensure we won't be sending any emails
if Rails.env.development? &&
     ActionMailer::Base.smtp_settings.slice(:address, :port) != { address: "localhost", port: 1025 }
  fail "In development mode, you should be using mailhog otherwise you might end up sending thousands of digest emails"
end

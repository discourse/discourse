# Load the rails application
require File.expand_path('../application', __FILE__)

# Initialize the rails application
Discourse::Application.initialize!

ActionMailer::Base.smtp_settings = {
  :address        => ENV['MAILGUN_SMTP_SERVER'],
  :port           => ENV['MAILGUN_SMTP_PORT'],
  :authentication => :plain,
  :user_name      => ENV['MAILGUN_SMTP_LOGIN'],
  :password       =>  ENV['MAILGUN_SMTP_PASSWORD'],
  :domain         => 'heroku.com',
  :enable_starttls_auto => true
}

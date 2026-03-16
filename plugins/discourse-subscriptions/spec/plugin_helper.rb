# frozen_string_literal: true

Dir[Rails.root.join("plugins/discourse-subscriptions/spec/fabricators/*.rb")].each { |f| require f }

require "stripe_mock"

RSpec.configure do |config|
  config.before(:each, :setup_stripe_mock) { StripeMock.start }
  config.after(:each, :setup_stripe_mock) { StripeMock.stop }
end

def setup_discourse_subscriptions
  SiteSetting.discourse_subscriptions_secret_key = "sk_test_fake_key"
  SiteSetting.discourse_subscriptions_enabled = true
end

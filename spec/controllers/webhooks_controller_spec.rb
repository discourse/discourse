require "rails_helper"

describe WebhooksController do

  let(:email) { "em@il.com" }

  before { $redis.del("bounce_score:#{email}:#{Date.today}") }

  context "mailgun" do

    it "works" do
      SiteSetting.mailgun_api_key = "pubkey-8221462f0c915af3f6f2e2df7aa5a493"
      token = "705a8ccd2ce932be8e98c221fe701c1b4a0afcb8bbd57726de"

      user = Fabricate(:user, email: email)
      email_log = Fabricate(:email_log, user: user, bounce_key: SecureRandom.hex)
      return_path = "foo+verp-#{email_log.bounce_key}@bar.com"

      $redis.del("mailgun_token_#{token}")
      WebhooksController.any_instance.expects(:mailgun_verify).returns(true)

      post :mailgun, "token" => token,
                     "timestamp" => Time.now.to_i,
                     "event" => "dropped",
                     "message-headers" => [["Return-Path", return_path]]

      expect(response).to be_success

      email_log.reload
      expect(email_log.bounced).to eq(true)
      expect(email_log.user.user_stat.bounce_score).to eq(2)
    end

  end

  context "sendgrid" do

    it "works" do
      user = Fabricate(:user, email: email)
      email_log = Fabricate(:email_log, user: user, message_id: "12345@il.com")

      post :sendgrid, "_json" => [
        {
          "email"     => email,
          "timestamp" => 1249948800,
          "smtp-id"   => "<12345@il.com>",
          "event"     => "bounce",
          "status"    => "5.0.0"
        }
      ]

      expect(response).to be_success

      email_log.reload
      expect(email_log.bounced).to eq(true)
      expect(email_log.user.user_stat.bounce_score).to eq(2)
    end

  end

end

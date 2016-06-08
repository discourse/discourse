require "rails_helper"

describe WebhooksController do
  before { $redis.flushall }

  let(:email) { "em@il.com" }
  let(:message_id) { "12345@il.com" }

  context "mailgun" do

    it "works" do
      SiteSetting.mailgun_api_key = "key-8221462f0c915af3f6f2e2df7aa5a493"

      user = Fabricate(:user, email: email)
      email_log = Fabricate(:email_log, user: user, message_id: message_id)

      WebhooksController.any_instance.expects(:mailgun_verify).returns(true)

      post :mailgun, "token" => "705a8ccd2ce932be8e98c221fe701c1b4a0afcb8bbd57726de",
                     "timestamp" => Time.now.to_i,
                     "event" => "dropped",
                     "Message-Id" => "<12345@il.com>"

      expect(response).to be_success

      email_log.reload
      expect(email_log.bounced).to eq(true)
      expect(email_log.user.user_stat.bounce_score).to eq(2)
    end

  end

  context "sendgrid" do

    it "works" do
      user = Fabricate(:user, email: email)
      email_log = Fabricate(:email_log, user: user, message_id: message_id)

      post :sendgrid, "_json" => [
        {
          "email"   => email,
          "smtp-id" => "<12345@il.com>",
          "event"   => "bounce",
          "status"  => "5.0.0"
        }
      ]

      expect(response).to be_success

      email_log.reload
      expect(email_log.bounced).to eq(true)
      expect(email_log.user.user_stat.bounce_score).to eq(2)
    end

  end

  context "mailjet" do

    it "works" do
      user = Fabricate(:user, email: email)
      email_log = Fabricate(:email_log, user: user, message_id: message_id)

      post :mailjet, {
        "event"       => "bounce",
        "hard_bounce" => true,
        "CustomID"    => message_id
      }

      expect(response).to be_success

      email_log.reload
      expect(email_log.bounced).to eq(true)
      expect(email_log.user.user_stat.bounce_score).to eq(2)
    end

  end

end

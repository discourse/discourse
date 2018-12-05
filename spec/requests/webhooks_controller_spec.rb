require "rails_helper"

describe WebhooksController do
  before { $redis.flushall }

  let(:email) { "em@il.com" }
  let(:message_id) { "12345@il.com" }

  context "mailgun" do
    it "works" do
      SiteSetting.mailgun_api_key = "key-8221462f0c915af3f6f2e2df7aa5a493"

      user = Fabricate(:user, email: email)
      email_log = Fabricate(:email_log, user: user, message_id: message_id, to_address: email)

      token = "705a8ccd2ce932be8e98c221fe701c1b4a0afcb8bbd57726de"
      timestamp = Time.now.to_i
      data = "#{timestamp}#{token}"
      signature = OpenSSL::HMAC.hexdigest(OpenSSL::Digest::SHA256.new, SiteSetting.mailgun_api_key, data)

      post "/webhooks/mailgun.json", params: {
        "token" => token,
        "timestamp" => timestamp,
        "event" => "dropped",
        "recipient" => email,
        "Message-Id" => "<12345@il.com>",
        "signature" => signature
      }

      expect(response.status).to eq(200)

      email_log.reload
      expect(email_log.bounced).to eq(true)
      expect(email_log.user.user_stat.bounce_score).to eq(2)
    end
  end

  context "sendgrid" do
    it "works" do
      user = Fabricate(:user, email: email)
      email_log = Fabricate(:email_log, user: user, message_id: message_id, to_address: email)

      post "/webhooks/sendgrid.json", params: {
        "_json" => [
          {
            "email" => email,
            "smtp-id" => "<12345@il.com>",
            "event" => "bounce",
            "status" => "5.0.0"
          }
        ]
      }

      expect(response.status).to eq(200)

      email_log.reload
      expect(email_log.bounced).to eq(true)
      expect(email_log.user.user_stat.bounce_score).to eq(2)
    end
  end

  context "mailjet" do
    it "works" do
      user = Fabricate(:user, email: email)
      email_log = Fabricate(:email_log, user: user, message_id: message_id, to_address: email)

      post "/webhooks/mailjet.json", params: {
        "event" => "bounce",
        "email" => email,
        "hard_bounce" => true,
        "CustomID" => message_id
      }

      expect(response.status).to eq(200)

      email_log.reload
      expect(email_log.bounced).to eq(true)
      expect(email_log.user.user_stat.bounce_score).to eq(2)
    end
  end

  context "mandrill" do
    it "works" do
      user = Fabricate(:user, email: email)
      email_log = Fabricate(:email_log, user: user, message_id: message_id, to_address: email)

      post "/webhooks/mandrill.json", params: {
        mandrill_events: [{
          "event" => "hard_bounce",
          "msg" => {
            "email" => email,
            "metadata" => {
              "message_id" => message_id
            }
          }
        }]
      }

      expect(response.status).to eq(200)

      email_log.reload
      expect(email_log.bounced).to eq(true)
      expect(email_log.user.user_stat.bounce_score).to eq(2)
    end
  end

  context "sparkpost" do
    it "works" do
      user = Fabricate(:user, email: email)
      email_log = Fabricate(:email_log, user: user, message_id: message_id, to_address: email)

      post "/webhooks/sparkpost.json", params: {
        "_json" => [{
          "msys" => {
            "message_event" => {
              "bounce_class" => 10,
              "rcpt_to" => email,
              "rcpt_meta" => {
                "message_id" => message_id
              }
            }
          }
        }]
      }

      expect(response.status).to eq(200)

      email_log.reload
      expect(email_log.bounced).to eq(true)
      expect(email_log.user.user_stat.bounce_score).to eq(2)
    end
  end
end

# frozen_string_literal: true

RSpec.describe WebhooksController do
  before { Discourse.redis.flushdb }

  let(:email) { "em@il.com" }
  let(:message_id) { "12345@il.com" }

  describe "#mailgun" do
    let(:token) { "705a8ccd2ce932be8e98c221fe701c1b4a0afcb8bbd57726de" }
    let(:timestamp) { Time.now.to_i }
    let(:data) { "#{timestamp}#{token}" }
    let(:signature) { OpenSSL::HMAC.hexdigest("SHA256", SiteSetting.mailgun_api_key, data) }

    before do
      SiteSetting.mailgun_api_key = "key-8221462f0c915af3f6f2e2df7aa5a493"
      ActionController::Base.allow_forgery_protection = true # Ensure the endpoint works, even with CSRF protection generally enabled
    end

    after { ActionController::Base.allow_forgery_protection = false }

    it "works (deprecated)" do
      user = Fabricate(:user, email: email)
      email_log = Fabricate(:email_log, user: user, message_id: message_id, to_address: email)

      post "/webhooks/mailgun.json",
           params: {
             "token" => token,
             "timestamp" => timestamp,
             "event" => "dropped",
             "recipient" => email,
             "Message-Id" => "<#{message_id}>",
             "signature" => signature,
             "error" => "smtp; 550-5.1.1 The email account that you tried to reach does not exist.",
             "code" => "5.1.1",
           }

      expect(response.status).to eq(200)

      email_log.reload
      expect(email_log.bounced).to eq(true)
      expect(email_log.bounce_error_code).to eq("5.1.1")
      expect(email_log.user.user_stat.bounce_score).to eq(SiteSetting.hard_bounce_score)
    end

    it "works (new)" do
      user = Fabricate(:user, email: email)
      email_log = Fabricate(:email_log, user: user, message_id: message_id, to_address: email)

      post "/webhooks/mailgun.json",
           params: {
             "signature" => {
               "token" => token,
               "timestamp" => timestamp,
               "signature" => signature,
             },
             "event-data" => {
               "event" => "failed",
               "severity" => "temporary",
               "recipient" => email,
               "message" => {
                 "headers" => {
                   "message-id" => message_id,
                 },
               },
             },
             "delivery-status" => {
               "message" =>
                 "smtp; 550-5.1.1 The email account that you tried to reach does not exist.",
               "code" => "5.1.1",
               "description" => "",
             },
           }

      expect(response.status).to eq(200)

      email_log.reload
      expect(email_log.bounced).to eq(true)
      expect(email_log.bounce_error_code).to eq("5.1.1")
      expect(email_log.user.user_stat.bounce_score).to eq(SiteSetting.soft_bounce_score)
    end
  end

  describe "#sendgrid" do
    it "works" do
      user = Fabricate(:user, email: email)
      email_log = Fabricate(:email_log, user: user, message_id: message_id, to_address: email)

      post "/webhooks/sendgrid.json",
           params: {
             "_json" => [
               {
                 "email" => email,
                 "smtp-id" => "<12345@il.com>",
                 "event" => "bounce",
                 "status" => "5.0.0",
               },
             ],
           }

      expect(response.status).to eq(200)

      email_log.reload
      expect(email_log.bounced).to eq(true)
      expect(email_log.bounce_error_code).to eq("5.0.0")
      expect(email_log.user.user_stat.bounce_score).to eq(SiteSetting.hard_bounce_score)
    end
  end

  describe "#mailjet" do
    it "works" do
      user = Fabricate(:user, email: email)
      email_log = Fabricate(:email_log, user: user, message_id: message_id, to_address: email)

      post "/webhooks/mailjet.json",
           params: {
             "event" => "bounce",
             "email" => email,
             "hard_bounce" => true,
             "CustomID" => message_id,
           }

      expect(response.status).to eq(200)

      email_log.reload
      expect(email_log.bounced).to eq(true)
      expect(email_log.bounce_error_code).to eq(nil) # mailjet doesn't give us this
      expect(email_log.user.user_stat.bounce_score).to eq(SiteSetting.hard_bounce_score)
    end
  end

  describe "#mailpace" do
    it "works" do
      user = Fabricate(:user, email: email)
      email_log = Fabricate(:email_log, user: user, message_id: message_id, to_address: email)

      post "/webhooks/mailpace.json", params: {
        "event": "email.bounced",
        "payload": {
            "status": "bounced",
            "to": email,
            "message_id": "<#{message_id}>",
        }
      }

      expect(response.status).to eq(200)

      email_log.reload
      expect(email_log.bounced).to eq(true)
      expect(email_log.bounce_error_code).to eq(nil) # mailpace doesn't give us this
      expect(email_log.user.user_stat.bounce_score).to eq(SiteSetting.hard_bounce_score)
    end


    it "soft bounces" do
      user = Fabricate(:user, email: email)
      email_log = Fabricate(:email_log, user: user, message_id: message_id, to_address: email)

      post "/webhooks/mailpace.json", params: {
        "event": "email.bounced",
        "payload": {
            "status": "bounced",
            "to": email,
            "message_id": "<#{message_id}>",
        }
      }

      expect(response.status).to eq(200)

      email_log.reload
      expect(email_log.bounced).to eq(true)
      expect(email_log.bounce_error_code).to eq(nil) # mailpace doesn't give us this
      expect(email_log.user.user_stat.bounce_score).to eq(SiteSetting.soft_bounce_score)
    end
  end

  describe "#mandrill" do
    it "works" do
      user = Fabricate(:user, email: email)
      email_log = Fabricate(:email_log, user: user, message_id: message_id, to_address: email)

      post "/webhooks/mandrill.json",
           params: {
             mandrill_events: [
               {
                 "event" => "hard_bounce",
                 "msg" => {
                   "email" => email,
                   "diag" => "5.1.1",
                   :"bounce_description" =>
                     "smtp; 550-5.1.1 The email account that you tried to reach does not exist.",
                   "metadata" => {
                     "message_id" => message_id,
                   },
                 },
               },
             ].to_json,
           }

      expect(response.status).to eq(200)

      email_log.reload
      expect(email_log.bounced).to eq(true)
      expect(email_log.bounce_error_code).to eq("5.1.1")
      expect(email_log.user.user_stat.bounce_score).to eq(SiteSetting.hard_bounce_score)
    end
  end

  describe "#mandrill_head" do
    it "works" do
      head "/webhooks/mandrill.json"

      expect(response.status).to eq(200)
    end
  end

  describe "#postmark" do
    it "works" do
      user = Fabricate(:user, email: email)
      email_log = Fabricate(:email_log, user: user, message_id: message_id, to_address: email)

      post "/webhooks/postmark.json",
           params: {
             "Type" => "HardBounce",
             "MessageID" => message_id,
             "Email" => email,
           }
      expect(response.status).to eq(200)

      email_log.reload
      expect(email_log.bounced).to eq(true)
      expect(email_log.bounce_error_code).to eq(nil) # postmark doesn't give us this
      expect(email_log.user.user_stat.bounce_score).to eq(SiteSetting.hard_bounce_score)
    end
    it "soft bounces" do
      user = Fabricate(:user, email: email)
      email_log = Fabricate(:email_log, user: user, message_id: message_id, to_address: email)

      post "/webhooks/postmark.json",
           params: {
             "Type" => "SoftBounce",
             "MessageID" => message_id,
             "Email" => email,
           }
      expect(response.status).to eq(200)

      email_log.reload
      expect(email_log.bounced).to eq(true)
      expect(email_log.bounce_error_code).to eq(nil) # postmark doesn't give us this
      expect(email_log.user.user_stat.bounce_score).to eq(SiteSetting.soft_bounce_score)
    end
  end

  describe "#sparkpost" do
    it "works" do
      user = Fabricate(:user, email: email)
      email_log = Fabricate(:email_log, user: user, message_id: message_id, to_address: email)

      post "/webhooks/sparkpost.json",
           params: {
             "_json" => [
               {
                 "msys" => {
                   "message_event" => {
                     "bounce_class" => 10,
                     "error_code" => "554",
                     "rcpt_to" => email,
                     "rcpt_meta" => {
                       "message_id" => message_id,
                     },
                   },
                 },
               },
             ],
           }

      expect(response.status).to eq(200)

      email_log.reload
      expect(email_log.bounced).to eq(true)
      expect(email_log.user.user_stat.bounce_score).to eq(SiteSetting.hard_bounce_score)
    end
  end
end

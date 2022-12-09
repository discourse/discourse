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

    it "verifies signatures" do
      SiteSetting.sendgrid_verification_key =
        "MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE83T4O/n84iotIvIW4mdBgQ/7dAfSmpqIM8kF9mN1flpVKS3GRqe62gw+2fNNRaINXvVpiglSI8eNEc6wEA3F+g=="

      post "/webhooks/sendgrid.json",
           headers: {
             "X-Twilio-Email-Event-Webhook-Signature" =>
               "MEUCIGHQVtGj+Y3LkG9fLcxf3qfI10QysgDWmMOVmxG0u6ZUAiEAyBiXDWzM+uOe5W0JuG+luQAbPIqHh89M15TluLtEZtM=",
             "X-Twilio-Email-Event-Webhook-Timestamp" => "1600112502",
           },
           params:
             "[{\"email\":\"hello@world.com\",\"event\":\"dropped\",\"reason\":\"Bounced Address\",\"sg_event_id\":\"ZHJvcC0xMDk5NDkxOS1MUnpYbF9OSFN0T0doUTRrb2ZTbV9BLTA\",\"sg_message_id\":\"LRzXl_NHStOGhQ4kofSm_A.filterdrecv-p3mdw1-756b745b58-kmzbl-18-5F5FC76C-9.0\",\"smtp-id\":\"<LRzXl_NHStOGhQ4kofSm_A@ismtpd0039p1iad1.sendgrid.net>\",\"timestamp\":1600112492}]\r\n"

      expect(response.status).to eq(200)
    end

    it "returns error if signature verification fails" do
      SiteSetting.sendgrid_verification_key =
        "MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE83T4O/n84iotIvIW4mdBgQ/7dAfSmpqIM8kF9mN1flpVKS3GRqe62gw+2fNNRaINXvVpiglSI8eNEc6wEA3F+g=="

      post "/webhooks/sendgrid.json",
           headers: {
             "X-Twilio-Email-Event-Webhook-Signature" =>
               "MEUCIQCtIHJeH93Y+qpYeWrySphQgpNGNr/U+UyUlBkU6n7RAwIgJTz2C+8a8xonZGi6BpSzoQsbVRamr2nlxFDWYNH3j/0=",
             "X-Twilio-Email-Event-Webhook-Timestamp" => "1600112502",
           },
           params:
             "[{\"email\":\"hello@world.com\",\"event\":\"dropped\",\"reason\":\"Bounced Address\",\"sg_event_id\":\"ZHJvcC0xMDk5NDkxOS1MUnpYbF9OSFN0T0doUTRrb2ZTbV9BLTA\",\"sg_message_id\":\"LRzXl_NHStOGhQ4kofSm_A.filterdrecv-p3mdw1-756b745b58-kmzbl-18-5F5FC76C-9.0\",\"smtp-id\":\"<LRzXl_NHStOGhQ4kofSm_A@ismtpd0039p1iad1.sendgrid.net>\",\"timestamp\":1600112492}]\r\n"

      expect(response.status).to eq(406)
    end

    it "returns error if signature is invalid" do
      SiteSetting.sendgrid_verification_key = "foo"

      post "/webhooks/sendgrid.json",
           headers: {
             "X-Twilio-Email-Event-Webhook-Signature" =>
               "MEUCIQCtIHJeH93Y+qpYeWrySphQgpNGNr/U+UyUlBkU6n7RAwIgJTz2C+8a8xonZGi6BpSzoQsbVRamr2nlxFDWYNH3j/0=",
             "X-Twilio-Email-Event-Webhook-Timestamp" => "1600112502",
           },
           params:
             "[{\"email\":\"hello@world.com\",\"event\":\"dropped\",\"reason\":\"Bounced Address\",\"sg_event_id\":\"ZHJvcC0xMDk5NDkxOS1MUnpYbF9OSFN0T0doUTRrb2ZTbV9BLTA\",\"sg_message_id\":\"LRzXl_NHStOGhQ4kofSm_A.filterdrecv-p3mdw1-756b745b58-kmzbl-18-5F5FC76C-9.0\",\"smtp-id\":\"<LRzXl_NHStOGhQ4kofSm_A@ismtpd0039p1iad1.sendgrid.net>\",\"timestamp\":1600112492}]\r\n"

      expect(response.status).to eq(406)
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

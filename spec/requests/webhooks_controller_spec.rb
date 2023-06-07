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

    it "verifies signatures" do
      SiteSetting.mailjet_webhook_token = "foo"
      user = Fabricate(:user, email: email)
      email_log = Fabricate(:email_log, user: user, message_id: message_id, to_address: email)

      post "/webhooks/mailjet.json?t=foo",
           params: {
             "event" => "bounce",
             "email" => email,
             "hard_bounce" => true,
             "CustomID" => message_id,
           }

      expect(response.status).to eq(200)
      expect(email_log.reload.bounced).to eq(true)
    end

    it "returns error if signature verification fails" do
      SiteSetting.mailjet_webhook_token = "foo"
      user = Fabricate(:user, email: email)
      email_log = Fabricate(:email_log, user: user, message_id: message_id, to_address: email)

      post "/webhooks/mailjet.json?t=bar",
           params: {
             "event" => "bounce",
             "email" => email,
             "hard_bounce" => true,
             "CustomID" => message_id,
           }

      expect(response.status).to eq(406)
      expect(email_log.reload.bounced).to eq(false)
    end
  end

  describe "#mailpace" do
    it "works" do
      user = Fabricate(:user, email: email)
      email_log = Fabricate(:email_log, user: user, message_id: message_id, to_address: email)

      post "/webhooks/mailpace.json",
           params: {
             event: "email.bounced",
             payload: {
               status: "bounced",
               to: email,
               message_id: "<#{message_id}>",
             },
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

      post "/webhooks/mailpace.json",
           params: {
             event: "email.deferred",
             payload: {
               status: "deferred",
               to: email,
               message_id: "<#{message_id}>",
             },
           }

      expect(response.status).to eq(200)

      email_log.reload
      expect(email_log.bounced).to eq(true)
      expect(email_log.bounce_error_code).to eq(nil) # mailpace doesn't give us this
      expect(email_log.user.user_stat.bounce_score).to eq(SiteSetting.soft_bounce_score)
    end
  end

  describe "#mandrill" do
    let(:payload) do
      "mandrill_events=%5B%7B%22event%22%3A%22hard_bounce%22%2C%22msg%22%3A%7B%22email%22%3A%22em%40il.com%22%2C%22diag%22%3A%225.1.1%22%2C%22bounce_description%22%3A%22smtp%3B+550-5.1.1+The+email+account+that+you+tried+to+reach+does+not+exist.%22%2C%22metadata%22%3A%7B%22message_id%22%3A%2212345%40il.com%22%7D%7D%7D%5D"
    end

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

    it "verifies signatures" do
      SiteSetting.mandrill_authentication_key = "wr_JeJNO9OI65RFDrvk3Zw"

      post "/webhooks/mandrill.json",
           headers: {
             "X-Mandrill-Signature" => "Q5pCb903EjEqRZ99gZrlYKOfvIU=",
           },
           params: payload

      expect(response.status).to eq(200)
    end

    it "returns error if signature verification fails" do
      SiteSetting.mandrill_authentication_key = "wr_JeJNO9OI65RFDrvk3Zw"

      post "/webhooks/mandrill.json", headers: { "X-Mandrill-Signature" => "foo" }, params: payload

      expect(response.status).to eq(406)
    end

    it "returns error if signature is invalid" do
      SiteSetting.mandrill_authentication_key = "foo"

      post "/webhooks/mandrill.json",
           headers: {
             "X-Mandrill-Signature" => "Q5pCb903EjEqRZ99gZrlYKOfvIU=",
           },
           params: payload

      expect(response.status).to eq(406)
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

    it "verifies signatures" do
      SiteSetting.postmark_webhook_token = "foo"
      user = Fabricate(:user, email: email)
      email_log = Fabricate(:email_log, user: user, message_id: message_id, to_address: email)

      post "/webhooks/postmark.json?t=foo",
           params: {
             "Type" => "HardBounce",
             "MessageID" => message_id,
             "Email" => email,
           }

      expect(response.status).to eq(200)
      expect(email_log.reload.bounced).to eq(true)
    end

    it "returns error if signature verification fails" do
      SiteSetting.postmark_webhook_token = "foo"
      user = Fabricate(:user, email: email)
      email_log = Fabricate(:email_log, user: user, message_id: message_id, to_address: email)

      post "/webhooks/postmark.json?t=bar",
           params: {
             "Type" => "HardBounce",
             "MessageID" => message_id,
             "Email" => email,
           }

      expect(response.status).to eq(406)
      expect(email_log.reload.bounced).to eq(false)
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

    it "verifies signatures" do
      SiteSetting.sparkpost_webhook_token = "foo"
      user = Fabricate(:user, email: email)
      email_log = Fabricate(:email_log, user: user, message_id: message_id, to_address: email)

      post "/webhooks/sparkpost.json?t=foo",
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
      expect(email_log.reload.bounced).to eq(true)
    end

    it "returns error if signature verification fails" do
      SiteSetting.sparkpost_webhook_token = "foo"
      user = Fabricate(:user, email: email)
      email_log = Fabricate(:email_log, user: user, message_id: message_id, to_address: email)

      post "/webhooks/sparkpost.json?t=bar",
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

      expect(response.status).to eq(406)
      expect(email_log.reload.bounced).to eq(false)
    end
  end

  describe "#aws" do
    let(:payload) do
      {
        "Type" => "Notification",
        "Message" => {
          "notificationType" => "Bounce",
          :"bounce" => {
            "bounceType" => "Permanent",
            "reportingMTA" => "dns; email.example.com",
            :"bouncedRecipients" => [
              {
                "emailAddress" => email,
                "status" => "5.1.1",
                "action" => "failed",
                "diagnosticCode" => "smtp; 550 5.1.1 <#{email}>... User",
              },
            ],
            "bounceSubType" => "General",
            "timestamp" => "2016-01-27T14:59:38.237Z",
            "feedbackId" => "00000138111222aa-33322211-cccc-cccc-cccc-ddddaaaa068a-000000",
            "remoteMtaIp" => "127.0.2.0",
          },
          :"mail" => {
            "timestamp" => "2016-01-27T14:59:38.237Z",
            "source" => "john@example.com",
            "sourceArn" => "arn:aws:ses:us-east-1:888888888888:identity/example.com",
            "sourceIp" => "127.0.3.0",
            "sendingAccountId" => "123456789012",
            "callerIdentity" => "IAM_user_or_role_name",
            "messageId" => message_id,
            "destination" => [email, "jane@example.com", "mary@example.com", "richard@example.com"],
            "headersTruncated" => false,
            "headers" => [
              { "name" => "From", "value" => "\"John Doe\" <john@example.com>" },
              {
                "name" => "To",
                "value" =>
                  "\"Test\" <#{email}>, \"Jane Doe\" <jane@example.com>, \"Mary Doe\" <mary@example.com>, \"Richard Doe\" <richard@example.com>",
              },
              { "name" => "Message-ID", "value" => message_id },
              { "name" => "Subject", "value" => "Hello" },
              { "name" => "Content-Type", "value" => "text/plain; charset=\"UTF-8\"" },
              { "name" => "Content-Transfer-Encoding", "value" => "base64" },
              { "name" => "Date", "value" => "Wed, 27 Jan 2016 14:05:45 +0000" },
            ],
            "commonHeaders" => {
              "from" => ["John Doe <john@example.com>"],
              "date" => "Wed, 27 Jan 2016 14:05:45 +0000",
              "to" => [
                "\"Test\" <#{email}>, Jane Doe <jane@example.com>, Mary Doe <mary@example.com>, Richard Doe <richard@example.com>",
              ],
              "messageId" => message_id,
              "subject" => "Hello",
            },
          },
        }.to_json,
      }.to_json
    end

    before { Jobs.run_immediately! }

    it "works" do
      user = Fabricate(:user, email: email)
      email_log = Fabricate(:email_log, user: user, message_id: message_id, to_address: email)

      require "aws-sdk-sns"
      Aws::SNS::MessageVerifier.any_instance.stubs(:authentic?).with(payload).returns(true)

      post "/webhooks/aws.json", headers: { "RAW_POST_DATA" => payload }
      expect(response.status).to eq(200)

      email_log.reload
      expect(email_log.bounced).to eq(true)
      expect(email_log.user.user_stat.bounce_score).to eq(SiteSetting.hard_bounce_score)
    end
  end
end

# frozen_string_literal: true

RSpec.describe WebhooksController do
  before { Discourse.redis.flushdb }

  fab!(:email) { "em@il.com" }
  fab!(:message_id) { "12345@il.com" }
  fab!(:user) { Fabricate(:user, email:) }
  fab!(:email_log) { Fabricate(:email_log, user:, message_id:, to_address: email) }

  def expect_bounce(score:, error_code: nil)
    email_log.reload
    expect(email_log.bounced).to eq(true)
    expect(email_log.bounce_error_code).to eq(error_code)
    expect(email_log.user.user_stat.bounce_score).to eq(score)
  end

  def expect_no_bounce
    expect(email_log.reload.bounced).to eq(false)
  end

  describe "#mailgun" do
    let(:token) { "705a8ccd2ce932be8e98c221fe701c1b4a0afcb8bbd57726de" }
    let(:timestamp) { Time.now.to_i }
    let(:data) { "#{timestamp}#{token}" }
    let(:signature) { OpenSSL::HMAC.hexdigest("SHA256", SiteSetting.mailgun_api_key, data) }

    before do
      SiteSetting.mailgun_api_key = "key-8221462f0c915af3f6f2e2df7aa5a493"
      ActionController::Base.allow_forgery_protection = true
    end

    after { ActionController::Base.allow_forgery_protection = false }

    it "returns 406 when API key is missing" do
      SiteSetting.mailgun_api_key = ""

      post "/webhooks/mailgun.json",
           params: {
             "token" => token,
             "timestamp" => timestamp,
             "event" => "dropped",
             "recipient" => email,
             "Message-Id" => "<#{message_id}>",
             "signature" => signature,
           }

      expect(response.status).to eq(406)
    end

    it "processes legacy dropped events as hard bounces" do
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
      expect_bounce(score: SiteSetting.hard_bounce_score, error_code: "5.1.1")
    end

    it "processes legacy transient bounces as soft bounces" do
      post "/webhooks/mailgun.json",
           params: {
             "token" => token,
             "timestamp" => timestamp,
             "event" => "bounced",
             "recipient" => email,
             "Message-Id" => "<#{message_id}>",
             "signature" => signature,
             "error" => "smtp; 4.7.1 Temporary failure",
             "code" => "4.7.1",
           }

      expect(response.status).to eq(200)
      expect_bounce(score: SiteSetting.soft_bounce_score, error_code: "4.7.1")
    end

    it "processes new format temporary failures as soft bounces" do
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
               "code" => "4.7.1",
             },
           }

      expect(response.status).to eq(200)
      expect_bounce(score: SiteSetting.soft_bounce_score, error_code: "4.7.1")
    end

    it "processes new format permanent failures as hard bounces" do
      post "/webhooks/mailgun.json",
           params: {
             "signature" => {
               "token" => token,
               "timestamp" => timestamp,
               "signature" => signature,
             },
             "event-data" => {
               "event" => "failed",
               "severity" => "permanent",
               "recipient" => email,
               "message" => {
                 "headers" => {
                   "message-id" => message_id,
                 },
               },
             },
             "delivery-status" => {
               "code" => "5.1.1",
             },
           }

      expect(response.status).to eq(200)
      expect_bounce(score: SiteSetting.hard_bounce_score, error_code: "5.1.1")
    end

    it "returns 503 in readonly mode" do
      Discourse.enable_readonly_mode

      post "/webhooks/mailgun.json",
           params: {
             "token" => token,
             "timestamp" => timestamp,
             "event" => "dropped",
             "recipient" => email,
             "Message-Id" => "<#{message_id}>",
             "signature" => signature,
             "code" => "5.1.1",
           }

      expect(response.status).to eq(503)
      expect_no_bounce
    end
  end

  describe "#sendgrid" do
    before do
      SiteSetting.sendgrid_verification_key = "key"
      WebhooksController.any_instance.stubs(:valid_sendgrid_signature?).returns(true)
    end

    it "processes webhooks with a deprecation warning when verification key is missing" do
      SiteSetting.sendgrid_verification_key = ""

      post "/webhooks/sendgrid.json",
           params: {
             "_json" => [
               {
                 "email" => email,
                 "smtp-id" => "<#{message_id}>",
                 "event" => "bounce",
                 "status" => "5.0.0",
               },
             ],
           }

      expect(response.status).to eq(200)
      expect_bounce(score: SiteSetting.hard_bounce_score, error_code: "5.0.0")
    end

    it "returns 406 when signature is invalid" do
      WebhooksController.any_instance.stubs(:valid_sendgrid_signature?).returns(false)

      post "/webhooks/sendgrid.json",
           params: {
             "_json" => [
               {
                 "email" => email,
                 "smtp-id" => "<#{message_id}>",
                 "event" => "bounce",
                 "status" => "5.0.0",
               },
             ],
           }

      expect(response.status).to eq(406)
    end

    it "processes hard bounces" do
      post "/webhooks/sendgrid.json",
           params: {
             "_json" => [
               {
                 "email" => email,
                 "smtp-id" => "<#{message_id}>",
                 "event" => "bounce",
                 "status" => "5.0.0",
               },
             ],
           }

      expect(response.status).to eq(200)
      expect_bounce(score: SiteSetting.hard_bounce_score, error_code: "5.0.0")
    end

    it "processes soft bounces with transient failure status" do
      post "/webhooks/sendgrid.json",
           params: {
             "_json" => [
               {
                 "email" => email,
                 "smtp-id" => "<#{message_id}>",
                 "event" => "bounce",
                 "status" => "4.0.0",
               },
             ],
           }

      expect(response.status).to eq(200)
      expect_bounce(score: SiteSetting.soft_bounce_score, error_code: "4.0.0")
    end

    it "processes dropped events as hard bounces" do
      post "/webhooks/sendgrid.json",
           params: {
             "_json" => [
               {
                 "email" => email,
                 "smtp-id" => "<#{message_id}>",
                 "event" => "dropped",
                 "status" => "5.0.0",
               },
             ],
           }

      expect(response.status).to eq(200)
      expect_bounce(score: SiteSetting.hard_bounce_score, error_code: "5.0.0")
    end

    it "defaults to error code 5.1.2 for blocked bounces without status" do
      post "/webhooks/sendgrid.json",
           params: {
             "_json" => [
               {
                 "email" => email,
                 "smtp-id" => "<#{message_id}>",
                 "event" => "bounce",
                 "type" => "blocked",
               },
             ],
           }

      expect(response.status).to eq(200)
      expect_bounce(score: SiteSetting.hard_bounce_score, error_code: "5.1.2")
    end
  end

  describe "#mailjet" do
    let(:bounce_params) do
      { "event" => "bounce", "email" => email, "hard_bounce" => true, "CustomID" => message_id }
    end

    it "processes webhooks with a deprecation warning when webhook token is missing" do
      post "/webhooks/mailjet.json", params: bounce_params

      expect(response.status).to eq(200)
      expect_bounce(score: SiteSetting.hard_bounce_score)
    end

    context "with a valid webhook token" do
      before { SiteSetting.mailjet_webhook_token = "foo" }

      it "processes hard bounces" do
        post "/webhooks/mailjet.json?t=foo", params: bounce_params

        expect(response.status).to eq(200)
        expect_bounce(score: SiteSetting.hard_bounce_score)
      end

      it "processes soft bounces" do
        post "/webhooks/mailjet.json?t=foo",
             params: [
               {
                 "event" => "bounce",
                 "email" => email,
                 "hard_bounce" => false,
                 "CustomID" => message_id,
               },
             ].to_json,
             headers: {
               "CONTENT_TYPE" => "application/json",
             }

        expect(response.status).to eq(200)
        expect_bounce(score: SiteSetting.soft_bounce_score)
      end

      it "rejects wrong token" do
        post "/webhooks/mailjet.json?t=bar", params: bounce_params

        expect(response.status).to eq(406)
        expect_no_bounce
      end

      it "rejects missing token param" do
        post "/webhooks/mailjet.json", params: bounce_params

        expect(response.status).to eq(406)
        expect_no_bounce
      end
    end
  end

  describe "#mailpace" do
    let(:bounce_params) do
      {
        event: "email.bounced",
        payload: {
          status: "bounced",
          to: email,
          message_id: "<#{message_id}>",
        },
      }
    end

    it "processes webhooks with a deprecation warning when verification key is missing" do
      post "/webhooks/mailpace.json", params: bounce_params

      expect(response.status).to eq(200)
      expect_bounce(score: SiteSetting.hard_bounce_score)
    end

    it "returns 406 when signature is invalid" do
      SiteSetting.mailpace_verification_key = "key"
      WebhooksController.any_instance.stubs(:valid_mailpace_signature?).returns(false)

      post "/webhooks/mailpace.json", params: bounce_params
      expect(response.status).to eq(406)
    end

    context "with a valid verification key" do
      before do
        SiteSetting.mailpace_verification_key = "key"
        WebhooksController.any_instance.stubs(:valid_mailpace_signature?).returns(true)
      end

      it "processes hard bounces" do
        post "/webhooks/mailpace.json", params: bounce_params

        expect(response.status).to eq(200)
        expect_bounce(score: SiteSetting.hard_bounce_score)
      end

      it "processes soft bounces" do
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
        expect_bounce(score: SiteSetting.soft_bounce_score)
      end
    end
  end

  describe "#mandrill" do
    def mandrill_events_json(event: "hard_bounce", diag: "5.1.1")
      [
        {
          "event" => event,
          "msg" => {
            "email" => email,
            "diag" => diag,
            "bounce_description" =>
              "smtp; 550-5.1.1 The email account that you tried to reach does not exist.",
            "metadata" => {
              "message_id" => message_id,
            },
          },
        },
      ].to_json
    end

    it "processes webhooks with a deprecation warning when authentication key is missing" do
      post "/webhooks/mandrill.json", params: { mandrill_events: mandrill_events_json }

      expect(response.status).to eq(200)
      expect_bounce(score: SiteSetting.hard_bounce_score, error_code: "5.1.1")
    end

    it "returns 406 when signature is invalid" do
      SiteSetting.mandrill_authentication_key = "key"
      WebhooksController.any_instance.stubs(:valid_mandrill_signature?).returns(false)

      post "/webhooks/mandrill.json", params: { mandrill_events: mandrill_events_json }

      expect(response.status).to eq(406)
    end

    context "with a valid authentication key" do
      before do
        SiteSetting.mandrill_authentication_key = "key"
        WebhooksController.any_instance.stubs(:valid_mandrill_signature?).returns(true)
      end

      it "processes hard bounces" do
        post "/webhooks/mandrill.json", params: { mandrill_events: mandrill_events_json }

        expect(response.status).to eq(200)
        expect_bounce(score: SiteSetting.hard_bounce_score, error_code: "5.1.1")
      end

      it "processes soft bounces" do
        post "/webhooks/mandrill.json",
             params: {
               mandrill_events: mandrill_events_json(event: "soft_bounce", diag: "4.7.1"),
             }

        expect(response.status).to eq(200)
        expect_bounce(score: SiteSetting.soft_bounce_score, error_code: "4.7.1")
      end
    end
  end

  describe "#mandrill_head" do
    it "returns 200" do
      head "/webhooks/mandrill.json"
      expect(response.status).to eq(200)
    end
  end

  describe "#postmark" do
    let(:bounce_params) { { "Type" => "HardBounce", "MessageID" => message_id, "Email" => email } }

    it "processes webhooks with a deprecation warning when webhook token is missing" do
      post "/webhooks/postmark.json", params: bounce_params

      expect(response.status).to eq(200)
      expect_bounce(score: SiteSetting.hard_bounce_score)
    end

    context "with a valid webhook token" do
      before { SiteSetting.postmark_webhook_token = "foo" }

      it "processes hard bounces" do
        post "/webhooks/postmark.json?t=foo", params: bounce_params

        expect(response.status).to eq(200)
        expect_bounce(score: SiteSetting.hard_bounce_score)
      end

      it "processes soft bounces" do
        post "/webhooks/postmark.json?t=foo",
             params: {
               "Type" => "SoftBounce",
               "MessageID" => message_id,
               "Email" => email,
             }

        expect(response.status).to eq(200)
        expect_bounce(score: SiteSetting.soft_bounce_score)
      end

      it "rejects wrong token" do
        post "/webhooks/postmark.json?t=bar", params: bounce_params

        expect(response.status).to eq(406)
        expect_no_bounce
      end

      it "rejects missing token param" do
        post "/webhooks/postmark.json", params: bounce_params

        expect(response.status).to eq(406)
        expect_no_bounce
      end
    end
  end

  describe "#sparkpost" do
    let(:bounce_params) do
      {
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
    end

    it "processes webhooks with a deprecation warning when webhook token is missing" do
      post "/webhooks/sparkpost.json", params: bounce_params

      expect(response.status).to eq(200)
      expect_bounce(score: SiteSetting.hard_bounce_score)
    end

    context "with a valid webhook token" do
      before { SiteSetting.sparkpost_webhook_token = "foo" }

      it "processes hard bounces" do
        post "/webhooks/sparkpost.json?t=foo", params: bounce_params

        expect(response.status).to eq(200)
        expect_bounce(score: SiteSetting.hard_bounce_score)
      end

      it "processes soft bounces" do
        post "/webhooks/sparkpost.json?t=foo",
             params: {
               "_json" => [
                 {
                   "msys" => {
                     "message_event" => {
                       "bounce_class" => 20,
                       "error_code" => "450",
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
        expect_bounce(score: SiteSetting.soft_bounce_score)
      end

      it "rejects wrong token" do
        post "/webhooks/sparkpost.json?t=bar", params: bounce_params

        expect(response.status).to eq(406)
        expect_no_bounce
      end

      it "rejects missing token param" do
        post "/webhooks/sparkpost.json", params: bounce_params

        expect(response.status).to eq(406)
        expect_no_bounce
      end
    end
  end

  describe "#aws" do
    let(:payload) do
      {
        "Type" => "Notification",
        "Message" => {
          "notificationType" => "Bounce",
          "bounce" => {
            "bounceType" => "Permanent",
            "reportingMTA" => "dns; email.example.com",
            "bouncedRecipients" => [
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
          "mail" => {
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

    it "processes bounce notifications" do
      require "aws-sdk-sns"
      Aws::SNS::MessageVerifier.any_instance.stubs(:authentic?).with(payload).returns(true)

      post "/webhooks/aws.json", headers: { "RAW_POST_DATA" => payload }

      expect(response.status).to eq(200)
      expect_bounce(score: SiteSetting.hard_bounce_score, error_code: "5.1.1")
    end
  end
end

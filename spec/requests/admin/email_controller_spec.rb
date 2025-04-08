# frozen_string_literal: true

RSpec.describe Admin::EmailController do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)

  describe "#server_settings" do
    context "when logged in as an admin" do
      before do
        sign_in(admin)
        Admin::EmailController
          .any_instance
          .expects(:action_mailer_settings)
          .returns(username: "username", password: "secret")
      end

      it "does not include the password in the response" do
        get "/admin/email/server-settings.json"
        mail_settings = response.parsed_body["settings"]

        expect(mail_settings.select { |setting| setting["name"] == "password" }).to be_empty
      end
    end

    shared_examples "email settings inaccessible" do
      it "denies access with a 404 response" do
        get "/admin/email/server-settings.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["settings"]).to be_nil
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "email settings inaccessible"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "email settings inaccessible"
    end
  end

  describe "#test" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "raises an error without the email parameter" do
        post "/admin/email/test.json"
        expect(response.status).to eq(400)
      end

      context "with an email address" do
        it "enqueues a test email job" do
          post "/admin/email/test.json", params: { email_address: "eviltrout@test.domain" }

          expect(response.status).to eq(200)
          expect(ActionMailer::Base.deliveries.map(&:to).flatten).to include(
            "eviltrout@test.domain",
          )
        end
      end

      context "with SiteSetting.disable_emails" do
        fab!(:eviltrout) { Fabricate(:evil_trout) }
        fab!(:admin)

        it 'bypasses disable when setting is "yes"' do
          SiteSetting.disable_emails = "yes"
          post "/admin/email/test.json", params: { email_address: admin.email }

          expect(ActionMailer::Base.deliveries.first.to).to contain_exactly(admin.email)

          incoming = response.parsed_body
          expect(incoming["sent_test_email_message"]).to eq(I18n.t("admin.email.sent_test"))
        end

        it 'bypasses disable when setting is "non-staff"' do
          SiteSetting.disable_emails = "non-staff"

          post "/admin/email/test.json", params: { email_address: eviltrout.email }

          expect(ActionMailer::Base.deliveries.first.to).to contain_exactly(eviltrout.email)

          incoming = response.parsed_body
          expect(incoming["sent_test_email_message"]).to eq(I18n.t("admin.email.sent_test"))
        end

        it 'works when setting is "no"' do
          SiteSetting.disable_emails = "no"

          post "/admin/email/test.json", params: { email_address: eviltrout.email }

          expect(ActionMailer::Base.deliveries.first.to).to contain_exactly(eviltrout.email)

          incoming = response.parsed_body
          expect(incoming["sent_test_email_message"]).to eq(I18n.t("admin.email.sent_test"))
        end
      end
    end

    shared_examples "email tests not allowed" do
      it "prevents email tests with a 404 response" do
        post "/admin/email/test.json", params: { email_address: "eviltrout@test.domain" }

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "email tests not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "email tests not allowed"
    end
  end

  describe "#preview_digest" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "raises an error without the last_seen_at parameter" do
        get "/admin/email/preview-digest.json"
        expect(response.status).to eq(400)
      end

      it "returns the right response when username is invalid" do
        get "/admin/email/preview-digest.json",
            params: {
              last_seen_at: 1.week.ago,
              username: "somerandomeusername",
            }

        expect(response.status).to eq(400)
      end

      it "previews the digest" do
        get "/admin/email/preview-digest.json",
            params: {
              last_seen_at: 1.week.ago,
              username: admin.username,
            }
        expect(response.status).to eq(200)
      end
    end

    shared_examples "preview digest inaccessible" do
      it "denies access with a 404 response" do
        get "/admin/email/preview-digest.json",
            params: {
              last_seen_at: 1.week.ago,
              username: moderator.username,
            }

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "preview digest inaccessible"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "preview digest inaccessible"
    end
  end

  describe "#send_digest" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "sends the digest" do
        post "/admin/email/send-digest.json",
             params: {
               last_seen_at: 1.week.ago,
               username: admin.username,
               email: email("previous_replies"),
             }
        expect(response.status).to eq(200)
      end
    end
  end

  describe "#handle_mail" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "returns a bad request if neither email parameter is present" do
        post "/admin/email/handle_mail.json"
        expect(response.status).to eq(400)
        expect(response.body).to include("param is missing")
      end

      it "should enqueue the right job, and show a deprecation warning (email_encoded param should be used)" do
        expect_enqueued_with(
          job: :process_email,
          args: {
            mail: email("cc"),
            retry_on_rate_limit: true,
            source: :handle_mail,
          },
        ) { post "/admin/email/handle_mail.json", params: { email: email("cc") } }
        expect(response.status).to eq(200)
        expect(response.body).to eq(
          "warning: the email parameter is deprecated. all POST requests to this route should be sent with a base64 strict encoded email_encoded parameter instead. email has been received and is queued for processing",
        )
      end

      it "should enqueue the right job, decoding the raw email param" do
        expect_enqueued_with(
          job: :process_email,
          args: {
            mail: email("cc"),
            retry_on_rate_limit: true,
            source: :handle_mail,
          },
        ) do
          post "/admin/email/handle_mail.json",
               params: {
                 email_encoded: Base64.strict_encode64(email("cc")),
               }
        end
        expect(response.status).to eq(200)
        expect(response.body).to eq("email has been received and is queued for processing")
      end

      it "retries enqueueing with forced UTF-8 encoding when encountering Encoding::UndefinedConversionError" do
        post "/admin/email/handle_mail.json",
             params: {
               email_encoded: Base64.strict_encode64(email("encoding_undefined_conversion")),
             }
        expect(response.status).to eq(200)
        expect(response.body).to eq("email has been received and is queued for processing")
      end
    end

    shared_examples "email handling not allowed" do
      it "prevents email handling with a 404 response" do
        post "/admin/email/handle_mail.json",
             params: {
               email_encoded: Base64.strict_encode64(email("cc")),
             }

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "email handling not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "email handling not allowed"
    end
  end

  describe "#advanced_test" do
    let(:email) { <<~EMAIL }
      From: "somebody" <somebody@example.com>
      To: someone@example.com
      Date: Mon, 3 Dec 2018 00:00:00 -0000
      Subject: This is some subject
      Content-Type: text/plain; charset="UTF-8"

      Hello, this is a test!

      ---

      This part should be elided.
    EMAIL

    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "should ..." do
        post "/admin/email/advanced-test.json", params: { email: email }

        expect(response.status).to eq(200)
        incoming = response.parsed_body
        expect(incoming["format"]).to eq(1)
        expect(incoming["text"]).to eq("Hello, this is a test!")
        expect(incoming["elided"]).to eq("---\n\nThis part should be elided.")
      end
    end

    shared_examples "advanced email tests not allowed" do
      it "prevents advanced email tests with a 404 response" do
        post "/admin/email/advanced-test.json", params: { email: email }

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "advanced email tests not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "advanced email tests not allowed"
    end
  end
end

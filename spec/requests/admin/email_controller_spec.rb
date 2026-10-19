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

  describe "#smtp_should_reject" do
    before { sign_in(admin) }

    it "does not reject with no params" do
      get "/admin/email/smtp_should_reject.json"
      expect(response.status).to eq(200)
      result = response.parsed_body

      expect(result["reject"]).to be false
    end

    it "does not reject with blank to/from" do
      get "/admin/email/smtp_should_reject.json", params: { from: "", to: "" }
      expect(response.status).to eq(200)
      result = response.parsed_body

      expect(result["reject"]).to be false
    end

    it "does not reject with blank to" do
      get "/admin/email/smtp_should_reject.json", params: { from: "bilbo@shire.net", to: "" }
      expect(response.status).to eq(200)
      result = response.parsed_body

      expect(result["reject"]).to be false
    end

    it "does not reject with blank from" do
      get "/admin/email/smtp_should_reject.json", params: { from: "", to: "frodo@shire.net" }
      expect(response.status).to eq(200)
      result = response.parsed_body

      expect(result["reject"]).to be false
    end

    it "does not reject with to/from specified" do
      get "/admin/email/smtp_should_reject.json",
          params: {
            from: "bilbo@shire.net",
            to: "frodo@shire.net",
          }
      expect(response.status).to eq(200)
      result = response.parsed_body

      expect(result["reject"]).to be false
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

      context "when test sends are restricted to the current admin" do
        before { SiteSetting.restrict_admin_email_test_sends_to_self = true }

        it "allows primary and secondary account email addresses" do
          secondary_email = Fabricate(:secondary_email, user: admin)
          ActionMailer::Base.deliveries.clear

          [admin.email, secondary_email.email].each do |email_address|
            post "/admin/email/test.json", params: { email_address: }

            expect(response.status).to eq(200)
            expect(ActionMailer::Base.deliveries.last.to).to contain_exactly(email_address)
          end
        end

        it "rejects email addresses that do not belong to the current admin" do
          ActionMailer::Base.deliveries.clear

          expect do
            post "/admin/email/test.json", params: { email_address: user.email }
          end.not_to change { ActionMailer::Base.deliveries.length }

          expect(response.status).to eq(400)
          expect(response.parsed_body["errors"].join).to include(
            I18n.t("email_settings.test_email_restricted"),
          )
        end
      end

      context "with SiteSetting.disable_emails" do
        fab!(:eviltrout, :evil_trout)
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

  describe "#preview_types" do
    it "returns the editable email template catalog to admins" do
      sign_in(admin)

      get "/admin/email/preview-types.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["email_templates"]).to include(
        {
          "id" => "system_messages.backup_failed",
          "title" => I18n.t("system_messages.backup_failed.title"),
        },
      )
    end

    it "denies access to non-admins" do
      sign_in(user)

      get "/admin/email/preview-types.json"

      expect(response.status).to eq(404)
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

      it "previews the digest without creating an unsubscribe key" do
        expect do
          get "/admin/email/preview-digest.json",
              params: {
                last_seen_at: 1.week.ago,
                username: admin.username,
              }
        end.not_to change { UnsubscribeKey.count }

        expect(response.status).to eq(200)
      end

      it "returns no preview when the digest has no content" do
        get "/admin/email/preview-digest.json",
            params: {
              last_seen_at: 1.week.ago,
              username: admin.username,
            }

        expect(response.status).to eq(200)
        expect(response.parsed_body).to eq(
          "subject" => nil,
          "html_content" => "",
          "text_content" => "",
        )
      end

      it "previews the digest in the requested locale" do
        Fabricate(:topic, created_at: 1.day.ago)

        get "/admin/email/preview-digest.json",
            params: {
              last_seen_at: 1.week.ago,
              username: admin.username,
              locale: "fr",
            }

        expect(response.status).to eq(200)
        rendered_contents = response.parsed_body.values_at("html_content", "text_content")
        french_label = I18n.t("user_notifications.digest.new_topics", locale: :fr)
        english_label = I18n.t("user_notifications.digest.new_topics", locale: :en)
        expect(rendered_contents).to all(include(french_label))
        preview = Nokogiri::HTML5.parse(response.parsed_body["html_content"])
        expect(preview.at_css("html")["lang"]).to eq("fr")
        rendered_contents.each do |rendered_content|
          expect(rendered_content).not_to include(english_label)
        end
      end

      it "rejects an unsupported preview locale" do
        get "/admin/email/preview-digest.json",
            params: {
              last_seen_at: 1.week.ago,
              username: admin.username,
              locale: "unsupported",
            }

        expect(response.status).to eq(400)
      end

      it "previews password reset messages without creating credentials" do
        preview_token = Admin::EmailController::PREVIEW_PASSWORD_RESET_TOKEN
        preview_code = Admin::EmailController::PREVIEW_LOGIN_CODE
        reset_link_preview = nil
        reset_code_preview = nil

        expect do
          get "/admin/email/preview-digest.json",
              params: {
                username: admin.username,
                email_type: "password_reset",
                locale: "fr",
              }
          expect(response.status).to eq(200)
          reset_link_preview = response.parsed_body

          get "/admin/email/preview-digest.json",
              params: {
                username: admin.username,
                email_type: "password_reset_code",
                locale: "fr",
              }
          expect(response.status).to eq(200)
          reset_code_preview = response.parsed_body
        end.not_to change { EmailToken.count }

        expect(reset_link_preview.values_at("html_content", "text_content")).to all(
          include("/u/password-reset/#{preview_token}"),
        )
        expect(reset_link_preview["text_content"]).to include(
          I18n.t(
            "user_notifications.forgot_password.text_body_template",
            locale: :fr,
            site_name: SiteSetting.title,
            base_url: Discourse.base_url,
            email_token: preview_token,
          ),
        )
        expect(reset_code_preview.values_at("html_content", "text_content")).to all(
          include(preview_code),
        )
      end

      it "previews representative messages without creating credentials" do
        expected_content = {
          "email_login_code" => Admin::EmailController::PREVIEW_LOGIN_CODE,
          "signup" => Admin::EmailController::PREVIEW_EMAIL_TOKEN,
          "activation_reminder" => Admin::EmailController::PREVIEW_EMAIL_TOKEN,
          "email_login" => Admin::EmailController::PREVIEW_EMAIL_TOKEN,
          "admin_login" => Admin::EmailController::PREVIEW_EMAIL_TOKEN,
          "account_created" => Admin::EmailController::PREVIEW_EMAIL_TOKEN,
          "confirm_new_email" => Admin::EmailController::PREVIEW_EMAIL_TOKEN,
          "test_email" => Discourse.base_url,
        }

        expect do
          expected_content.each do |email_type, content|
            get "/admin/email/preview-digest.json",
                params: {
                  username: admin.username,
                  email_type:,
                  locale: "en",
                }

            expect(response.status).to eq(200)
            expect(response.parsed_body["subject"]).to be_present
            expect(response.parsed_body["text_content"]).to include(content)
          end
        end.not_to change { EmailToken.count }
      end

      it "previews representative messages in the requested locale" do
        get "/admin/email/preview-digest.json",
            params: {
              username: admin.username,
              email_type: "signup",
              locale: "fr",
            }

        expect(response.status).to eq(200)
        expect(response.parsed_body["text_content"]).to include(
          I18n.t(
            "user_notifications.signup.text_body_template",
            locale: :fr,
            site_name: SiteSetting.title,
            base_url: Discourse.base_url,
            email_token: Admin::EmailController::PREVIEW_EMAIL_TOKEN,
          ),
        )
      end

      it "previews editable templates with unresolved substitutions" do
        get "/admin/email/preview-digest.json",
            params: {
              username: admin.username,
              email_type: "template:system_messages.backup_failed",
              locale: "en",
            }

        expect(response.status).to eq(200)
        expect(response.parsed_body["subject"]).to eq(
          I18n.t("system_messages.backup_failed.subject_template"),
        )
        expect(response.parsed_body.values_at("html_content", "text_content")).to all(
          include("%{logs}"),
        )
      end

      it "previews the other form of pluralized templates" do
        get "/admin/email/preview-digest.json",
            params: {
              username: admin.username,
              email_type: "template:system_messages.reviewables_reminder",
              locale: "en",
            }

        expect(response.status).to eq(200)
        expect(response.parsed_body["text_content"]).to include("%{mentions}", "%{count}")
      end

      it "rejects an unknown template preview" do
        get "/admin/email/preview-digest.json",
            params: {
              username: admin.username,
              email_type: "template:unsupported",
              locale: "en",
            }

        expect(response.status).to eq(400)
      end

      it "rejects an unsupported preview email type" do
        get "/admin/email/preview-digest.json",
            params: {
              username: admin.username,
              email_type: "unsupported",
              locale: "en",
            }

        expect(response.status).to eq(400)
      end

      it "does not turn a post attribute into executable HTML" do
        attacker = Fabricate(:user, trust_level: TrustLevel[1])
        payload =
          '<a class="hashtag-cooked" data-slug="&lt;img src=x onerror=alert(1)&gt;">ignored</a>'

        freeze_time 1.day.ago do
          sign_in(attacker)
          post "/posts.json", params: { title: "Attacker-created topic", raw: payload }
          expect(response.status).to eq(200)
        end

        sign_in(admin)
        get "/admin/email/preview-digest.json",
            params: {
              last_seen_at: 1.week.ago,
              username: admin.username,
            }

        expect(response.status).to eq(200)
        preview = Nokogiri::HTML5.parse(response.parsed_body["html_content"])
        expect(preview.at_css("img[onerror='alert(1)']")).to be_nil
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
               email: admin.email,
             }
        expect(response.status).to eq(200)
      end

      it "sends the digest in the requested locale" do
        Fabricate(:topic, created_at: 1.day.ago)
        ActionMailer::Base.deliveries.clear

        post "/admin/email/send-digest.json",
             params: {
               last_seen_at: 1.month.ago,
               username: admin.username,
               email: admin.email,
               locale: "fr",
             }

        expect(response.status).to eq(200)
        message = ActionMailer::Base.deliveries.last
        rendered_contents = [message.html_part.body.to_s, message.text_part.body.to_s]
        expect(rendered_contents).to all(
          include(I18n.t("user_notifications.digest.new_topics", locale: :fr)),
        )
      end

      it "sends password reset previews without creating credentials" do
        ActionMailer::Base.deliveries.clear
        email_token_count = EmailToken.count
        messages = {}

        %w[password_reset password_reset_code].each do |email_type|
          post "/admin/email/send-digest.json",
               params: {
                 username: admin.username,
                 email: admin.email,
                 email_type:,
                 locale: "en",
               }

          expect(response.status).to eq(200)
          messages[email_type] = ActionMailer::Base.deliveries.last
        end

        expect(EmailToken.count).to eq(email_token_count)
        expect(
          [
            messages["password_reset"].html_part.body.to_s,
            messages["password_reset"].text_part.body.to_s,
          ],
        ).to all(
          include("/u/password-reset/#{Admin::EmailController::PREVIEW_PASSWORD_RESET_TOKEN}"),
        )
        expect(
          [
            messages["password_reset_code"].html_part.body.to_s,
            messages["password_reset_code"].text_part.body.to_s,
          ],
        ).to all(include(Admin::EmailController::PREVIEW_LOGIN_CODE))
      end

      it "sends literal template previews" do
        ActionMailer::Base.deliveries.clear

        post "/admin/email/send-digest.json",
             params: {
               username: admin.username,
               email: admin.email,
               email_type: "template:system_messages.backup_failed",
               locale: "en",
             }

        expect(response.status).to eq(200)
        message = ActionMailer::Base.deliveries.last
        expect(message.subject).to eq(I18n.t("system_messages.backup_failed.subject_template"))
        expect([message.html_part.body.to_s, message.text_part.body.to_s]).to all(
          include("%{logs}"),
        )
      end

      it "sends the digest to the requested email without unsubscribe links" do
        Fabricate(:topic, created_at: 1.day.ago)
        ActionMailer::Base.deliveries.clear

        expect {
          post "/admin/email/send-digest.json",
               params: {
                 last_seen_at: 1.month.ago,
                 username: user.username,
                 email: "attacker@evil.com",
               }
        }.not_to change { UnsubscribeKey.count }

        expect(response.status).to eq(200)
        expect(response.parsed_body["success"]).to eq("OK")

        message = ActionMailer::Base.deliveries.last
        expect(message.to).to eq(["attacker@evil.com"])
        expect(message.html_part.body.to_s).not_to include("/email/unsubscribe/")
        expect(message.text_part.body.to_s).not_to include("/email/unsubscribe/")
        expect(message.header["List-Unsubscribe"].to_s).to be_blank
        expect(message.header["List-Unsubscribe-Post"].to_s).to be_blank
      end

      context "when test sends are restricted to the current admin" do
        before { SiteSetting.restrict_admin_email_test_sends_to_self = true }

        it "allows the admin's address and rejects other recipients" do
          ActionMailer::Base.deliveries.clear

          post "/admin/email/send-digest.json",
               params: {
                 username: admin.username,
                 email: admin.email,
                 email_type: "template:test_mailer",
                 locale: "en",
               }

          expect(response.status).to eq(200)
          expect(ActionMailer::Base.deliveries.last.to).to contain_exactly(admin.email)

          expect do
            post "/admin/email/send-digest.json",
                 params: {
                   username: admin.username,
                   email: user.email,
                   email_type: "template:test_mailer",
                   locale: "en",
                 }
          end.not_to change { ActionMailer::Base.deliveries.length }

          expect(response.status).to eq(400)
          expect(response.parsed_body["errors"].join).to include(
            I18n.t("email_settings.test_email_restricted"),
          )
        end
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      it "denies test sends" do
        expect do
          post "/admin/email/send-digest.json",
               params: {
                 username: user.username,
                 email: user.email,
                 email_type: "template:test_mailer",
                 locale: "en",
               }
        end.not_to change { ActionMailer::Base.deliveries.length }

        expect(response.status).to eq(404)
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

      it "enqueues the email job and warns that email_encoded is preferred" do
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

      it "decodes the raw email and enqueues the email job" do
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

      it "normalizes invalid UTF-8 bytes before enqueueing" do
        post "/admin/email/handle_mail.json",
             params: {
               email_encoded: Base64.strict_encode64(email("encoding_undefined_conversion")),
             }
        expect(response.status).to eq(200)
        expect(response.body).to eq("email has been received and is queued for processing")
      end

      it "enqueues the email job when the site is archived" do
        SiteSetting.site_archived = true

        expect_enqueued_with(job: :process_email, args: { mail: email("cc") }) do
          post "/admin/email/handle_mail.json",
               params: {
                 email_encoded: Base64.strict_encode64(email("cc")),
               }
        end
        expect(response.status).to eq(200)
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

      it "returns parsed email text and elided content" do
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

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

      it "keeps cross-group email references from granting access to private conversations" do
        SiteSetting.email_in = true
        receiving_group =
          Fabricate(
            :group,
            incoming_email: "inbox@example.com",
            allow_unknown_sender_topic_replies: true,
          )
        victim_group = Fabricate(:group, allow_unknown_sender_topic_replies: false)
        private_post = Fabricate(:private_message_post, raw: "Confidential victim conversation")
        private_post.topic.allowed_groups << victim_group
        message_id = "discourse/post/#{private_post.id}@#{Discourse.current_hostname}"
        Fabricate(
          :incoming_email,
          post: private_post,
          topic: private_post.topic,
          message_id: message_id,
          created_via: IncomingEmail.created_via_types[:group_smtp],
        )

        sign_in(user)
        get "/t/#{private_post.topic_id}.json"
        expect(response.status).to eq(404)
        expect(response.body).not_to include(private_post.raw)

        attacker_mail = <<~MAIL
          From: #{user.email}
          To: #{receiving_group.incoming_email}
          Subject: Re: Support request
          Date: #{Time.current.rfc2822}
          Message-ID: <outsider-reply@example.com>
          In-Reply-To: <#{message_id}>
          Content-Type: text/plain; charset=UTF-8

          Please add this reply to the conversation.
        MAIL

        sign_in(admin)
        Jobs.run_immediately!
        post "/admin/email/handle_mail.json",
             params: {
               email_encoded: Base64.strict_encode64(attacker_mail),
             }
        expect(response.status).to eq(200)
        expect(response.body).to eq("email has been received and is queued for processing")

        incoming = IncomingEmail.find_by!(message_id: "outsider-reply@example.com")
        expect(incoming.rejection_message).to be_blank
        expect(incoming.post_id).to be_present

        sign_in(user)
        get "/t/#{private_post.topic_id}.json"
        expect(response.body).not_to include(private_post.raw)
        expect(response.status).to eq(404)
        expect(private_post.topic.topic_allowed_users.exists?(user_id: user.id)).to eq(false)
        expect(private_post.topic.posts.count).to eq(1)
        expect(Post.last.topic.allowed_groups).to contain_exactly(receiving_group)
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

      it "bounds the body of a message sent to a group inbox" do
        Jobs.run_immediately!
        SiteSetting.email_in = true
        SiteSetting.max_post_length = 100
        Fabricate(:group, incoming_email: "team@bar.com")

        mail = <<~EMAIL
          From: Someone <someone@example.com>
          To: team@bar.com
          Subject: A very long email
          Date: #{Time.now.rfc2822}
          Content-Type: text/plain; charset=UTF-8

          #{"This body is long enough to exceed the maximum post length. " * 20}
        EMAIL

        expect {
          post "/admin/email/handle_mail.json",
               params: {
                 email_encoded: Base64.strict_encode64(mail),
               }
        }.to change(Post, :count).by(1)

        expect(response.status).to eq(200)
        expect(Post.last.raw.length).to be <= SiteSetting.max_post_length
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

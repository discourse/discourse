# frozen_string_literal: true

RSpec.describe Admin::EmailLogsController do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)
  fab!(:email_log)

  describe "#sent" do
    fab!(:post)
    fab!(:email_log) { Fabricate(:email_log, post: post) }

    let(:post_reply_key) { Fabricate(:post_reply_key, post: post, user: email_log.user) }

    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "should return the right response" do
        get "/admin/email-logs/sent.json"

        expect(response.status).to eq(200)
        log = response.parsed_body.first
        expect(log["id"]).to eq(email_log.id)
        expect(log["reply_key"]).to eq(nil)

        post_reply_key

        get "/admin/email-logs/sent.json"

        expect(response.status).to eq(200)
        log = response.parsed_body.first
        expect(log["id"]).to eq(email_log.id)
        expect(log["reply_key"]).to eq(post_reply_key.reply_key)
        expect(log["post_id"]).to eq(post.id)
        expect(log["post_url"]).to eq(post.url)
      end

      it "should be able to filter by reply key" do
        email_log_2 = Fabricate(:email_log, post: post)

        post_reply_key_2 =
          Fabricate(
            :post_reply_key,
            post: post,
            user: email_log_2.user,
            reply_key: "2d447423-c625-4fb9-8717-ff04ac60eee8",
          )

        %w[17ff04 2d447423c6254fb98717ff04ac60eee8].each do |reply_key|
          get "/admin/email-logs/sent.json", params: { reply_key: reply_key }

          expect(response.status).to eq(200)

          logs = response.parsed_body

          expect(logs.size).to eq(1)
          expect(logs.first["reply_key"]).to eq(post_reply_key_2.reply_key)
        end
      end

      it "should be able to filter by smtp_transaction_response" do
        email_log_2 = Fabricate(:email_log, smtp_transaction_response: <<~RESPONSE)
          250 Ok: queued as pYoKuQ1aUG5vdpgh-k2K11qcpF4C1ZQ5qmvmmNW25SM=@mailhog.example
        RESPONSE

        get "/admin/email-logs/sent.json", params: { smtp_transaction_response: "pYoKu" }

        expect(response.status).to eq(200)

        logs = response.parsed_body

        expect(logs.size).to eq(1)
        expect(logs.first["smtp_transaction_response"]).to eq(email_log_2.smtp_transaction_response)
      end

      context "when type is group_smtp and filter param is address" do
        let(:email_type) { "group_smtp" }
        let(:target_email) { user.email }

        it "should be able to filter across both to address and cc addresses" do
          other_email = "foo@bar.com"
          another_email = "forty@two.com"
          email_log_matching_to_address =
            Fabricate(:email_log, to_address: target_email, email_type: email_type)
          email_log_matching_cc_address =
            Fabricate(
              :email_log,
              to_address: admin.email,
              cc_addresses: "#{other_email};#{target_email};#{another_email}",
              email_type: email_type,
            )

          get "/admin/email-logs/sent.json", params: { address: target_email, type: email_type }

          expect(response.status).to eq(200)
          logs = response.parsed_body
          expect(logs.size).to eq(2)
          email_log_found_with_to_address =
            logs.find { |log| log["id"] == email_log_matching_to_address.id }
          expect(email_log_found_with_to_address["cc_addresses"]).to be_nil
          expect(email_log_found_with_to_address["to_address"]).to eq target_email
          email_log_found_with_cc_address =
            logs.find { |log| log["id"] == email_log_matching_cc_address.id }
          expect(email_log_found_with_cc_address["to_address"]).not_to eq target_email
          expect(email_log_found_with_cc_address["cc_addresses"]).to contain_exactly(
            target_email,
            other_email,
            another_email,
          )
        end
      end
    end

    shared_examples "sent emails inaccessible" do
      it "denies access with a 404 response" do
        get "/admin/email-logs/sent.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "sent emails inaccessible"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "sent emails inaccessible"
    end
  end

  describe "#skipped" do
    # fab!(:user)
    fab!(:log1) { Fabricate(:skipped_email_log, user: user, created_at: 20.minutes.ago) }
    fab!(:log2) { Fabricate(:skipped_email_log, created_at: 10.minutes.ago) }

    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "succeeds" do
        get "/admin/email-logs/skipped.json"

        expect(response.status).to eq(200)

        logs = response.parsed_body

        expect(logs.first["id"]).to eq(log2.id)
        expect(logs.last["id"]).to eq(log1.id)
      end

      context "when filtered by username" do
        it "should return the right response" do
          get "/admin/email-logs/skipped.json", params: { user: user.username }

          expect(response.status).to eq(200)

          logs = response.parsed_body

          expect(logs.count).to eq(1)
          expect(logs.first["id"]).to eq(log1.id)
        end
      end
    end

    shared_examples "skipped emails inaccessible" do
      it "denies access with a 404 response" do
        get "/admin/email-logs/skipped.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "skipped emails inaccessible"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "skipped emails inaccessible"
    end
  end

  describe "#rejected" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "should provide a string for a blank error" do
        Fabricate(:incoming_email, error: "")
        get "/admin/email-logs/rejected.json"
        expect(response.status).to eq(200)
        rejected = response.parsed_body
        expect(rejected.first["error"]).to eq(I18n.t("emails.incoming.unrecognized_error"))
      end
    end

    shared_examples "rejected emails inaccessible" do
      it "denies access with a 404 response" do
        get "/admin/email-logs/rejected.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "rejected emails inaccessible"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "rejected emails inaccessible"
    end
  end

  describe "#incoming" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "should provide a string for a blank error" do
        incoming_email = Fabricate(:incoming_email, error: "")
        get "/admin/email-logs/incoming/#{incoming_email.id}.json"
        expect(response.status).to eq(200)
        incoming = response.parsed_body
        expect(incoming["error"]).to eq(I18n.t("emails.incoming.unrecognized_error"))
      end
    end

    shared_examples "incoming emails inaccessible" do
      it "denies access with a 404 response" do
        incoming_email = Fabricate(:incoming_email, error: "")

        get "/admin/email-logs/incoming/#{incoming_email.id}.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "incoming emails inaccessible"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "incoming emails inaccessible"
    end
  end

  describe "#incoming_from_bounced" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "raises an error when the email log entry does not exist" do
        get "/admin/email-logs/incoming_from_bounced/12345.json"
        expect(response.status).to eq(404)

        json = response.parsed_body
        expect(json["errors"]).to include("Discourse::InvalidParameters")
      end

      it "raises an error when the email log entry is not marked as bounced" do
        get "/admin/email-logs/incoming_from_bounced/#{email_log.id}.json"
        expect(response.status).to eq(404)

        json = response.parsed_body
        expect(json["errors"]).to include("Discourse::InvalidParameters")
      end

      context "when bounced email log entry exists" do
        fab!(:email_log) { Fabricate(:email_log, bounced: true, bounce_key: SecureRandom.hex) }
        let(:error_message) { "Email::Receiver::BouncedEmailError" }

        it "returns an incoming email sent to the reply_by_email_address" do
          SiteSetting.reply_by_email_address = "replies+%{reply_key}@example.com"

          Fabricate(
            :incoming_email,
            is_bounce: true,
            error: error_message,
            to_addresses: Email::Sender.bounce_address(email_log.bounce_key),
          )

          get "/admin/email-logs/incoming_from_bounced/#{email_log.id}.json"
          expect(response.status).to eq(200)

          json = response.parsed_body
          expect(json["error"]).to eq(error_message)
        end

        it "returns an incoming email sent to the notification_email address" do
          Fabricate(
            :incoming_email,
            is_bounce: true,
            error: error_message,
            to_addresses: SiteSetting.notification_email.sub("@", "+verp-#{email_log.bounce_key}@"),
          )

          get "/admin/email-logs/incoming_from_bounced/#{email_log.id}.json"
          expect(response.status).to eq(200)

          json = response.parsed_body
          expect(json["error"]).to eq(error_message)
        end

        it "returns an incoming email sent to the notification_email address" do
          SiteSetting.reply_by_email_address = "replies+%{reply_key}@subdomain.example.com"
          Fabricate(
            :incoming_email,
            is_bounce: true,
            error: error_message,
            to_addresses: "subdomain+verp-#{email_log.bounce_key}@example.com",
          )

          get "/admin/email-logs/incoming_from_bounced/#{email_log.id}.json"
          expect(response.status).to eq(200)

          json = response.parsed_body
          expect(json["error"]).to eq(error_message)
        end

        it "raises an error if the bounce_key is blank" do
          email_log.update(bounce_key: nil)

          get "/admin/email-logs/incoming_from_bounced/#{email_log.id}.json"
          expect(response.status).to eq(404)

          json = response.parsed_body
          expect(json["errors"]).to include("Discourse::InvalidParameters")
        end

        it "raises an error if there is no incoming email" do
          get "/admin/email-logs/incoming_from_bounced/#{email_log.id}.json"
          expect(response.status).to eq(404)

          json = response.parsed_body
          expect(json["errors"]).to include("Discourse::NotFound")
        end
      end
    end

    shared_examples "bounced incoming emails inaccessible" do
      it "denies access with a 404 response" do
        email_log = Fabricate(:email_log, bounced: true, bounce_key: SecureRandom.hex)
        error_message = "Email::Receiver::BouncedEmailError"
        SiteSetting.reply_by_email_address = "replies+%{reply_key}@example.com"

        Fabricate(
          :incoming_email,
          is_bounce: true,
          error: error_message,
          to_addresses: Email::Sender.bounce_address(email_log.bounce_key),
        )

        get "/admin/email-logs/incoming_from_bounced/#{email_log.id}.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "bounced incoming emails inaccessible"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "bounced incoming emails inaccessible"
    end
  end
end

# frozen_string_literal: true

RSpec.describe "Admin viewing email logs" do
  fab!(:admin)

  let(:admin_email_logs_page) { PageObjects::Pages::AdminEmailLogs.new }

  before { sign_in(admin) }

  describe "when viewing rejected email logs" do
    fab!(:rejected_incoming_email)
    fab!(:rejected_incoming_email_2, :rejected_incoming_email)

    it "allows an admin to view a list of rejected email logs and their details" do
      admin_email_logs_page.visit_rejected

      [rejected_incoming_email, rejected_incoming_email_2].each do |incoming_email|
        row = admin_email_logs_page.row_for(incoming_email)

        expect(row).to have_from_address(incoming_email.from_address)
        expect(row).to have_to_address(incoming_email.to_addresses)
        expect(row).to have_subject(incoming_email.subject)
        expect(row).to have_error(incoming_email.error)
      end
    end
  end

  describe "when viewing received email logs" do
    fab!(:incoming_email)
    fab!(:incoming_email_2, :incoming_email)

    it "allows an admin to view a list of received email logs and their details" do
      admin_email_logs_page.visit_received

      [incoming_email, incoming_email_2].each do |incoming_email|
        row = admin_email_logs_page.row_for(incoming_email)

        expect(row).to have_from_address(incoming_email.from_address)
        expect(row).to have_to_address(incoming_email.to_addresses)
        expect(row).to have_subject(incoming_email.subject)
      end
    end
  end

  describe "when viewing bounced email logs" do
    fab!(:bounced_email_log) { Fabricate(:email_log, bounced: true, email_type: "signup") }
    fab!(:bounced_email_log_2) { Fabricate(:email_log, bounced: true, email_type: "digest") }

    it "allows an admin to view a list of bounced email logs" do
      admin_email_logs_page.visit_bounced

      [bounced_email_log, bounced_email_log_2].each do |email_log|
        row = admin_email_logs_page.row_for(email_log)

        expect(row).to have_user(email_log.user.username)
        expect(row).to have_to_address(email_log.to_address)
        expect(row).to have_email_type(email_log.email_type)
      end
    end
  end

  describe "when viewing skipped email logs" do
    fab!(:skipped_email_log) do
      Fabricate(
        :skipped_email_log,
        user: Fabricate(:user),
        email_type: "signup",
        to_address: "skipped1@example.com",
        reason_type: SkippedEmailLog.reason_types[:exceeded_emails_limit],
      )
    end

    fab!(:skipped_email_log_2) do
      Fabricate(
        :skipped_email_log,
        user: Fabricate(:user),
        email_type: "digest",
        to_address: "skipped2@example.com",
        reason_type: SkippedEmailLog.reason_types[:custom],
        custom_reason: "Custom skip reason",
      )
    end

    it "allows an admin to view a list of skipped email logs" do
      admin_email_logs_page.visit_skipped

      [skipped_email_log, skipped_email_log_2].each do |email_log|
        row = admin_email_logs_page.row_for(email_log)

        expect(row).to have_user(email_log.user.username)
        expect(row).to have_to_address(email_log.to_address)
        expect(row).to have_email_type(email_log.email_type)
        expect(row).to have_skipped_reason(email_log.reason)
      end
    end
  end

  describe "when viewing sent email logs" do
    fab!(:post)
    fab!(:post_2, :post)

    fab!(:post_reply_key) do
      Fabricate(
        :post_reply_key,
        user: post.user,
        post: post,
        reply_key: "11111111-1111-1111-1111-111111111111",
      )
    end

    fab!(:post_reply_key_2) do
      Fabricate(
        :post_reply_key,
        user: post_2.user,
        post: post_2,
        reply_key: "22222222-2222-2222-2222-222222222222",
      )
    end

    fab!(:sent_email_log) do
      Fabricate(
        :email_log,
        user: post.user,
        post: post,
        to_address: "sent1@example.com",
        email_type: "signup",
        smtp_transaction_response: "250 2.0.0 OK",
      )
    end

    fab!(:sent_email_log_2) do
      Fabricate(
        :email_log,
        user: post_2.user,
        post: post_2,
        to_address: "sent2@example.com",
        email_type: "digest",
        smtp_transaction_response: "250 2.0.0 Accepted",
      )
    end

    it "allows an admin to view a list of sent email logs" do
      admin_email_logs_page.visit_sent

      [
        [sent_email_log, post_reply_key.reply_key],
        [sent_email_log_2, post_reply_key_2.reply_key],
      ].each do |email_log, expected_reply_key|
        row = admin_email_logs_page.row_for(email_log)

        expect(row).to have_user(email_log.user.username)
        expect(row).to have_to_address(email_log.to_address)
        expect(row).to have_email_type(email_log.email_type)
        expect(row).to have_reply_key(expected_reply_key.delete("-"))
        expect(row).to have_post_description(
          "#{email_log.post.topic.title} ##{email_log.post.post_number}",
        )
        expect(row).to have_smtp_response(email_log.smtp_transaction_response)
      end
    end
  end
end

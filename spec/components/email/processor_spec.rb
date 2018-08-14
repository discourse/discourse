require "rails_helper"
require "email/processor"

describe Email::Processor do

  let(:from) { "foo@bar.com" }

  context "when reply via email is too short" do
    let(:mail) { file_from_fixtures("email_reply_3.eml", "emails").read }
    let(:post) { Fabricate(:post) }
    let!(:user) { Fabricate(:user, email: "three@foo.com") }
    let!(:email_log) do
      Fabricate(:email_log,
        message_id: "35@foo.bar.mail", # don't change, based on fixture file "email_reply_3.eml"
        email_type: "user_posted",
        post_id: post.id,
        to_address: "asdas@dasdfd.com"
      )
    end

    before do
      SiteSetting.min_post_length = 1000
      SiteSetting.find_related_post_with_key = false
    end

    it "rejects reply and sends an email with custom error message" do
      begin
        receiver = Email::Receiver.new(mail)
        receiver.process!
      rescue Email::Receiver::TooShortPost => e
        error = e
      end

      expect(error.class).to eq(Email::Receiver::TooShortPost)
      processor = Email::Processor.new(mail)
      processor.process!

      rejection_raw = processor.send(:handle_failure, mail, error).body.raw_source

      count = SiteSetting.min_post_length
      destination = receiver.mail.to
      former_title = receiver.mail.subject

      expect(rejection_raw.gsub(/\r/, "")).to eq(
        I18n.t("system_messages.email_reject_post_too_short.text_body_template",
          count: count,
          destination: destination,
          former_title: former_title
        ).gsub(/\r/, "")
      )
    end
  end

  describe "rate limits" do

    let(:mail) { "From: #{from}\nTo: bar@foo.com\nSubject: FOO BAR\n\nFoo foo bar bar?" }
    let(:limit_exceeded) { RateLimiter::LimitExceeded.new(10) }

    before do
      Email::Receiver.any_instance.expects(:process!).raises(limit_exceeded)
    end

    it "enqueues a background job by default" do
      Jobs.expects(:enqueue).with(:process_email, mail: mail)
      Email::Processor.process!(mail)
    end

    it "doesn't enqueue a background job when retry is disabled" do
      Jobs.expects(:enqueue).with(:process_email, mail: mail).never
      expect { Email::Processor.process!(mail, false) }.to raise_error(limit_exceeded)
    end

  end

  context "known error" do

    let(:mail) { "From: #{from}\nTo: bar@foo.com" }
    let(:mail2) { "From: #{from}\nTo: foo@foo.com" }
    let(:mail3) { "From: #{from}\nTo: foobar@foo.com" }

    it "only sends one rejection email per day" do
      key = "rejection_email:#{[from]}:email_reject_empty:#{Date.today}"
      $redis.expire(key, 0)

      expect {
        Email::Processor.process!(mail)
      }.to change { EmailLog.count }.by(1)

      expect {
        Email::Processor.process!(mail2)
      }.to change { EmailLog.count }.by(0)

      freeze_time(Date.today + 1)

      key = "rejection_email:#{[from]}:email_reject_empty:#{Date.today}"
      $redis.expire(key, 0)

      expect {
        Email::Processor.process!(mail3)
      }.to change { EmailLog.count }.by(1)
    end
  end

  context "unrecognized error" do

    let(:mail) { "From: #{from}\nTo: bar@foo.com\nSubject: FOO BAR\n\nFoo foo bar bar?" }
    let(:mail2) { "From: #{from}\nTo: foo@foo.com\nSubject: BAR BAR\n\nBar bar bar bar?" }

    it "sends a rejection email on an unrecognized error" do
      Email::Processor.any_instance.stubs(:can_send_rejection_email?).returns(true)
      Email::Receiver.any_instance.stubs(:process_internal).raises("boom")
      Rails.logger.expects(:error)

      Email::Processor.process!(mail)
      expect(IncomingEmail.last.error).to             eq("boom")
      expect(IncomingEmail.last.rejection_message).to be_present
      expect(EmailLog.last.email_type).to             eq("email_reject_unrecognized_error")
    end

    it "sends more than one rejection email per day" do
      Email::Receiver.any_instance.stubs(:process_internal).raises("boom")
      key = "rejection_email:#{[from]}:email_reject_unrecognized_error:#{Date.today}"
      $redis.expire(key, 0)

      expect {
        Email::Processor.process!(mail)
      }.to change { EmailLog.count }.by(1)

      expect {
        Email::Processor.process!(mail2)
      }.to change { EmailLog.count }.by(1)
    end

  end

  context "from reply to email address" do

    let(:mail) { "From: reply@bar.com\nTo: reply@bar.com\nSubject: FOO BAR\n\nFoo foo bar bar?" }

    it "ignores the email" do
      Email::Receiver.any_instance.stubs(:process_internal).raises(Email::Receiver::FromReplyByAddressError.new)

      expect {
        Email::Processor.process!(mail)
      }.to change { EmailLog.count }.by(0)
    end

  end

  context "mailinglist mirror" do
    before do
      SiteSetting.email_in = true
      Fabricate(:mailinglist_mirror_category)
    end

    it "does not send rejection email" do
      Email::Receiver.any_instance.stubs(:process_internal).raises("boom")

      email = <<~EMAIL
        From: foo@example.com
        To: list@example.com
        Subject: Hello world
      EMAIL

      expect { Email::Processor.process!(email) }.to_not change { EmailLog.count }
    end
  end
end

require "rails_helper"
require "email/processor"

describe Email::Processor do

  let(:from) { "foo@bar.com" }

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

require "rails_helper"
require "email/processor"

describe Email::Processor do
  after do
    $redis.flushall
  end

  let(:from) { "foo@bar.com" }

  context "when reply via email is too short" do
    let(:mail) { file_from_fixtures("chinese_reply.eml", "emails").read }
    let(:post) { Fabricate(:post) }
    let(:user) { Fabricate(:user, email: 'discourse@bar.com') }

    let!(:post_reply_key) do
      Fabricate(:post_reply_key,
        user: user,
        post: post,
        reply_key: '4f97315cc828096c9cb34c6f1a0d6fe8'
      )
    end

    before do
      SiteSetting.email_in = true
      SiteSetting.reply_by_email_address = "reply+%{reply_key}@bar.com"
      SiteSetting.min_post_length = 1000
    end

    it "rejects reply and sends an email with custom error message" do
      processor = Email::Processor.new(mail)
      processor.process!

      rejection_raw = ActionMailer::Base.deliveries.first.body.raw_source

      count = SiteSetting.min_post_length
      destination = processor.receiver.mail.to
      former_title = processor.receiver.mail.subject

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
      begin
        @orig_logger = Rails.logger
        Rails.logger = @fake_logger = FakeLogger.new

        Email::Processor.any_instance.stubs(:can_send_rejection_email?).returns(true)
        Email::Receiver.any_instance.stubs(:process_internal).raises("boom")

        Email::Processor.process!(mail)

        errors = Rails.logger.errors
        expect(errors.size).to eq(1)
        expect(errors.first).to include("boom")

        incoming_email = IncomingEmail.last
        expect(incoming_email.error).to eq("boom")
        expect(incoming_email.rejection_message).to be_present

        expect(EmailLog.last.email_type).to eq("email_reject_unrecognized_error")
      ensure
        Rails.logger = @orig_logger
      end
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

  describe 'when replying to a post that is too old' do
    let(:mail) { file_from_fixtures("old_destination.eml", "emails").read }

    it 'rejects the email with the right response' do
      SiteSetting.disallow_reply_by_email_after_days = 2

      topic = Fabricate(:topic, id: 424242)
      post  = Fabricate(:post, topic: topic, id: 123456, created_at: 3.days.ago)

      processor = Email::Processor.new(mail)
      processor.process!

      rejection_raw = ActionMailer::Base.deliveries.first.body.to_s

      expect(rejection_raw).to eq(I18n.t("system_messages.email_reject_old_destination.text_body_template",
        destination: '["reply+4f97315cc828096c9cb34c6f1a0d6fe8@bar.com"]',
        former_title: 'Some Old Post',
        short_url: "#{Discourse.base_url}/p/#{post.id}",
        number_of_days: 2
      ))
    end
  end
end

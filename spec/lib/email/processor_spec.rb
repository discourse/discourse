# frozen_string_literal: true

require "email/processor"

RSpec.describe Email::Processor do
  after { Discourse.redis.flushdb }

  let(:from) { "foo@bar.com" }

  context "when reply via email is too short" do
    let(:mail) { file_from_fixtures("chinese_reply.eml", "emails").read }
    fab!(:post)
    fab!(:user) { Fabricate(:user, email: "discourse@bar.com", refresh_auto_groups: true) }

    fab!(:post_reply_key) do
      Fabricate(
        :post_reply_key,
        user: user,
        post: post,
        reply_key: "4f97315cc828096c9cb34c6f1a0d6fe8",
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
        I18n.t(
          "system_messages.email_reject_post_too_short.text_body_template",
          count: count,
          destination: destination,
          former_title: former_title,
        ).gsub(/\r/, ""),
      )
    end
  end

  describe "when mail is not set" do
    it "does not raise an error" do
      expect { Email::Processor.process!(nil) }.not_to raise_error
      expect { Email::Processor.process!("") }.not_to raise_error
    end
  end

  describe "rate limits" do
    let(:mail) { "From: #{from}\nTo: bar@foo.com\nSubject: FOO BAR\n\nFoo foo bar bar?" }
    let(:limit_exceeded) { RateLimiter::LimitExceeded.new(10) }

    before { Email::Receiver.any_instance.expects(:process!).raises(limit_exceeded) }

    it "enqueues a background job by default" do
      expect_enqueued_with(job: :process_email, args: { mail: mail }) do
        Email::Processor.process!(mail, retry_on_rate_limit: true)
      end
    end

    it "doesn't enqueue a background job when retry is disabled" do
      expect_not_enqueued_with(job: :process_email, args: { mail: mail }) do
        expect { Email::Processor.process!(mail, retry_on_rate_limit: false) }.to raise_error(
          limit_exceeded,
        )
      end
    end
  end

  describe "known error" do
    let(:mail) { "From: #{from}\nTo: bar@foo.com" }
    let(:mail2) { "From: #{from}\nTo: foo@foo.com" }
    let(:mail3) { "From: #{from}\nTo: foobar@foo.com" }

    it "only sends one rejection email per day" do
      key = "rejection_email:#{[from]}:email_reject_empty:#{Date.today}"
      Discourse.redis.expire(key, 0)

      expect { Email::Processor.process!(mail) }.to change { EmailLog.count }.by(1)

      expect { Email::Processor.process!(mail2) }.not_to change { EmailLog.count }

      freeze_time(Date.today + 1)

      key = "rejection_email:#{[from]}:email_reject_empty:#{Date.today}"
      Discourse.redis.expire(key, 0)

      expect { Email::Processor.process!(mail3) }.to change { EmailLog.count }.by(1)
    end
  end

  describe "unrecognized error" do
    let(:mail) do
      "Date: Fri, 15 Jan 2016 00:12:43 +0100\nFrom: #{from}\nTo: bar@foo.com\nSubject: FOO BAR\n\nFoo foo bar bar?"
    end
    let(:mail2) do
      "Date: Fri, 15 Jan 2016 00:12:43 +0100\nFrom: #{from}\nTo: foo@foo.com\nSubject: BAR BAR\n\nBar bar bar bar?"
    end
    let(:fake_logger) { FakeLogger.new }

    before { Rails.logger.broadcast_to(fake_logger) }

    after { Rails.logger.stop_broadcasting_to(fake_logger) }

    it "sends a rejection email on an unrecognized error" do
      Email::Processor.any_instance.stubs(:can_send_rejection_email?).returns(true)
      Email::Receiver.any_instance.stubs(:process_internal).raises("boom")

      Email::Processor.process!(mail)

      errors = fake_logger.errors
      expect(errors.size).to eq(1)
      expect(errors.first).to include("boom")

      incoming_email = IncomingEmail.last
      expect(incoming_email.error).to eq("RuntimeError")
      expect(incoming_email.rejection_message).to be_present

      expect(EmailLog.last.email_type).to eq("email_reject_unrecognized_error")
    end

    it "sends more than one rejection email per day" do
      Email::Receiver.any_instance.stubs(:process_internal).raises("boom")
      key = "rejection_email:#{[from]}:email_reject_unrecognized_error:#{Date.today}"
      Discourse.redis.expire(key, 0)

      expect { Email::Processor.process!(mail) }.to change { EmailLog.count }.by(1)

      expect { Email::Processor.process!(mail2) }.to change { EmailLog.count }.by(1)
    end
  end

  describe "from reply to email address" do
    let(:mail) do
      "Date: Fri, 15 Jan 2016 00:12:43 +0100\nFrom: reply@bar.com\nTo: reply@bar.com\nSubject: FOO BAR\n\nFoo foo bar bar?"
    end

    it "ignores the email" do
      Email::Receiver
        .any_instance
        .stubs(:process_internal)
        .raises(Email::Receiver::FromReplyByAddressError.new)

      expect { Email::Processor.process!(mail) }.not_to change { EmailLog.count }
    end
  end

  describe "mailinglist mirror" do
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

  describe "when replying to a post that is too old" do
    fab!(:user) { Fabricate(:user, email: "discourse@bar.com") }
    fab!(:topic)
    fab!(:post) { Fabricate(:post, topic: topic, created_at: 3.days.ago) }
    let(:mail) do
      file_from_fixtures("old_destination.eml", "emails").read.gsub(":post_id", post.id.to_s)
    end

    it "rejects the email with the right response" do
      SiteSetting.disallow_reply_by_email_after_days = 2
      processor = Email::Processor.new(mail)
      processor.process!

      rejection_raw = ActionMailer::Base.deliveries.first.body.to_s

      expect(rejection_raw).to eq(
        I18n.t(
          "system_messages.email_reject_old_destination.text_body_template",
          destination: '["reply+4f97315cc828096c9cb34c6f1a0d6fe8@bar.com"]',
          former_title: "Some Old Post",
          short_url: "#{Discourse.base_url}/p/#{post.id}",
          number_of_days: 2,
        ),
      )
    end
  end

  describe "when group email recipients exceeds maximum_recipients_per_new_group_email site setting" do
    let(:mail) { file_from_fixtures("cc.eml", "emails").read }

    it "rejects the email with the right response" do
      SiteSetting.maximum_recipients_per_new_group_email = 3

      processor = Email::Processor.new(mail)
      processor.process!

      rejection_raw = ActionMailer::Base.deliveries.first.body.to_s

      expect(rejection_raw).to eq(
        I18n.t(
          "system_messages.email_reject_too_many_recipients.text_body_template",
          destination: '["someone@else.com"]',
          former_title: "The more, the merrier",
          max_recipients_count: 3,
          base_url: Discourse.base_url,
        ),
      )
    end
  end
end

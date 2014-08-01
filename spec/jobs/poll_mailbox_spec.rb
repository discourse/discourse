require 'spec_helper'
require_dependency 'jobs/regular/process_post'

describe Jobs::PollMailbox do

  let!(:poller) { Jobs::PollMailbox.new }

  describe ".execute" do

    it "does no polling if pop3s_polling_enabled is false" do
      SiteSetting.expects(:pop3s_polling_enabled?).returns(false)
      poller.expects(:poll_pop3s).never

      poller.execute({})
    end

    describe "with pop3s_polling_enabled" do

      it "calls poll_pop3s" do
        SiteSetting.expects(:pop3s_polling_enabled?).returns(true)
        poller.expects(:poll_pop3s).once

        poller.execute({})
      end
    end

  end

  describe ".poll_pop3s" do

    it "logs an error on pop authentication error" do
      error = Net::POPAuthenticationError.new
      data = { limit_once_per: 1.hour, message_params: { error: error }}

      Net::POP3.expects(:start).raises(error)

      Discourse.expects(:handle_exception)

      poller.poll_pop3s
    end

  end

  # Testing mock for the email objects that you get
  # from Net::POP3.start { |pop| pop.mails }
  class MockPop3EmailObject
    def initialize(mail_string)
      @message = mail_string
      @delete_called = 0
    end

    def pop
      @message
    end

    def delete
      @delete_called += 1
    end

    # call 'assert email.deleted?' at the end of the test
    def deleted?
      @delete_called == 1
    end
  end

  describe "processing email B" do
    let(:category) { Fabricate(:category) }
    let(:user) { Fabricate(:user) }

    before do
      SiteSetting.email_in = true
      SiteSetting.reply_by_email_address = 'reply+%{reply_key}@discourse.example.com'
      category.email_in = 'incoming+amazing@discourse.example.com'
      category.save
      user.change_trust_level! :regular
      user.username = 'Jake'
      user.email = 'jake@email.example.com'
      user.save
    end

    describe "valid incoming email" do
      let(:email) { MockPop3EmailObject.new fixture_file('emails/valid_incoming.eml')}
      let(:expected_post) { fixture_file('emails/valid_incoming.cooked') }

      it "posts a new topic with the correct content" do

        poller.handle_mail(email)

        topic = Topic.where(category: category).where.not(id: category.topic_id).first
        assert topic.present?
        post = topic.posts.first
        assert_equal expected_post.strip, post.cooked.strip

        assert email.deleted?
      end
    end

    describe "valid reply" do
      let(:email) { MockPop3EmailObject.new fixture_file('emails/valid_reply.eml')}
      let(:expected_post) { fixture_file('emails/valid_reply.cooked')}
      let(:topic) { Fabricate(:topic) }
      let(:first_post) { Fabricate(:post, topic: topic, post_number: 1)}

      before do
        first_post.save
        EmailLog.create(to_address: 'jake@email.example.com',
                        email_type: 'user_posted',
                        reply_key: '59d8df8370b7e95c5a49fbf86aeb2c93',
                        post: first_post,
                        topic: topic)
      end

      pending "creates a new post with the correct content" do
        RejectionMailer.expects(:send_rejection).never
        Discourse.expects(:handle_exception).never

        poller.handle_mail(email)

        new_post = Post.where(topic: topic, post_number: 2)
        assert new_post.present?

        assert_equal expected_post.strip, new_post.cooked.strip

        assert email.deleted?
      end
    end


  end

  describe "processing email" do

    let!(:receiver) { mock }
    let!(:email_string) { fixture_file("emails/valid_incoming.eml") }
    let!(:email) { mock }

    before do
      email.stubs(:pop).returns(email_string)
      Email::Receiver.expects(:new).with(email_string).returns(receiver)
    end

    describe "all goes fine" do

      it "email gets deleted" do
        receiver.expects(:process)
        email.expects(:delete)

        poller.handle_mail(email)
      end
    end

    describe "raises Untrusted error" do

      it "sends a reply and deletes the email" do
        receiver.expects(:process).raises(Email::Receiver::UserNotSufficientTrustLevelError)
        email.expects(:delete)

        message = Mail::Message.new(email_string)
        Mail::Message.expects(:new).with(email_string).returns(message)

        client_message = mock
        sender_object = mock

        RejectionMailer.expects(:send_rejection).with(
            message.from, message.body, message.subject, message.to, :email_reject_trust_level
        ).returns(client_message)
        Email::Sender.expects(:new).with(client_message, :email_reject_trust_level).returns(sender_object)
        sender_object.expects(:send)

        poller.handle_mail(email)
      end
    end

    describe "raises error" do

      [ Email::Receiver::ProcessingError,
        Email::Receiver::EmailUnparsableError,
        Email::Receiver::EmptyEmailError,
        Email::Receiver::UserNotFoundError,
        Email::Receiver::EmailLogNotFound,
        ActiveRecord::Rollback,
        TypeError
      ].each do |exception|

        it "deletes email on #{exception}" do
          receiver.expects(:process).raises(exception)
          email.expects(:delete)

          Discourse.stubs(:handle_exception)

          poller.handle_mail(email)
        end

      end

    end
  end

end

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

  def expect_success
    poller.expects(:handle_failure).never
  end

  def expect_exception(clazz)
    poller.expects(:handle_failure).with(anything, instance_of(clazz))
  end

  describe "processing emails" do
    let(:category) { Fabricate(:category) }
    let(:user) { Fabricate(:user) }

    before do
      SiteSetting.email_in = true
      SiteSetting.reply_by_email_address = "reply+%{reply_key}@appmail.adventuretime.ooo"
      category.email_in = 'incoming+amazing@appmail.adventuretime.ooo'
      category.save
      user.change_trust_level! :regular
      user.username = 'Jake'
      user.email = 'jake@adventuretime.ooo'
      user.save
    end

    describe "a valid incoming email" do
      let(:email) {
        # this string replacing is kinda dumb
        str = fixture_file('emails/valid_incoming.eml')
        str = str.gsub("FROM", 'jake@adventuretime.ooo').gsub("TO", 'incoming+amazing@appmail.adventuretime.ooo')
        MockPop3EmailObject.new str
      }
      let(:expected_post) { fixture_file('emails/valid_incoming.cooked') }

      it "posts a new topic with the correct content" do
        expect_success

        poller.handle_mail(email)

        topic = Topic.where(category: category).where.not(id: category.topic_id).last
        topic.should be_present
        topic.title.should == "We should have a post-by-email-feature"

        post = topic.posts.first
        post.cooked.strip.should == expected_post.strip

        email.should be_deleted
      end

      describe "with insufficient trust" do
        before do
          user.change_trust_level! :newuser
        end

        it "raises a UserNotSufficientTrustLevelError" do
          expect_exception Email::Receiver::UserNotSufficientTrustLevelError

          poller.handle_mail(email)
        end

        it "posts the topic if allow_strangers is true" do
          begin
            category.email_in_allow_strangers = true
            category.save

            expect_success
            poller.handle_mail(email)
            topic = Topic.where(category: category).where.not(id: category.topic_id).last
            topic.should be_present
            topic.title.should == "We should have a post-by-email-feature"
          ensure
            category.email_in_allow_strangers = false
            category.save
          end
        end
      end
    end

    describe "a valid reply" do
      let(:email) { MockPop3EmailObject.new fixture_file('emails/valid_reply.eml')}
      let(:expected_post) { fixture_file('emails/valid_reply.cooked')}
      let(:topic) { Fabricate(:topic) }
      let(:first_post) { Fabricate(:post, topic: topic, post_number: 1)}

      before do
        first_post.save
        EmailLog.create(to_address: 'jake@email.example.com',
                        email_type: 'user_posted',
                        reply_key: '59d8df8370b7e95c5a49fbf86aeb2c93',
                        user: user,
                        post: first_post,
                        topic: topic)
      end

      it "creates a new post" do
        expect_success

        poller.handle_mail(email)

        new_post = Post.find_by(topic: topic, post_number: 2)
        assert new_post.present?
        assert_equal expected_post.strip, new_post.cooked.strip

        email.should be_deleted
      end

      describe "with the wrong reply key" do
        let(:email) { MockPop3EmailObject.new fixture_file('emails/wrong_reply_key.eml')}

        it "raises an EmailLogNotFound error" do
          expect_exception Email::Receiver::EmailLogNotFound

          poller.handle_mail(email)
          email.should be_deleted
        end
      end
    end

    describe "in failure conditions" do

      it "a valid reply without an email log raises an EmailLogNotFound error" do
        email = MockPop3EmailObject.new fixture_file('emails/valid_reply.eml')
        expect_exception Email::Receiver::EmailLogNotFound

        poller.handle_mail(email)
        email.should be_deleted
      end

      it "a no content reply raises an EmailUnparsableError" do
        email = MockPop3EmailObject.new fixture_file('emails/no_content_reply.eml')
        expect_exception Email::Receiver::EmailUnparsableError

        poller.handle_mail(email)
        email.should be_deleted
      end

      it "a fully empty email raises an EmptyEmailError" do
        email = MockPop3EmailObject.new fixture_file('emails/empty.eml')
        expect_exception Email::Receiver::EmptyEmailError

        poller.handle_mail(email)
        email.should be_deleted
      end


    end
  end

end

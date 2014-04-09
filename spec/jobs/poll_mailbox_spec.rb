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

    it "informs admins on pop authentication error" do
      error = Net::POPAuthenticationError.new
      data = { limit_once_per: 1.hour, message_params: { error: error }}

      Net::POP3.expects(:start).raises(error)
      GroupMessage.expects(:create).with("admins", :email_error_notification, data)

      poller.poll_pop3s
    end

  end

  describe "processing email" do

    let!(:receiver) { mock }
    let!(:email_string) { "EMAIL AS A STRING" }
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

        Mail::Message.expects(:new).with(email_string).returns(email)

        email.expects(:from)
        email.expects(:body)

        client_message = mock
        sender = mock

        RejectionMailer.expects(:send_trust_level).returns(client_message)
        Email::Sender.expects(:new).with(client_message, :email_reject_trust_level).returns(sender)
        sender.expects(:send)

        poller.handle_mail(email)
      end
    end

    describe "raises error" do

      [ Email::Receiver::ProcessingError,
        Email::Receiver::EmailUnparsableError,
        Email::Receiver::EmptyEmailError,
        Email::Receiver::UserNotFoundError,
        Email::Receiver::EmailLogNotFound,
      ].each do |exception|

        it "deletes email on #{exception}" do
          receiver.expects(:process).raises(exception)
          email.expects(:delete)

          poller.handle_mail(email)
        end

      end

      it "informs admins on any other error" do
        error = TypeError.new
        data = { limit_once_per: false, message_params: { source: email, error: error }}

        receiver.expects(:process).raises(error)
        email.expects(:delete)
        GroupMessage.expects(:create).with("admins", :email_error_notification, data)

        poller.handle_mail(email)
      end

    end
  end

end

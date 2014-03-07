# -*- encoding : utf-8 -*-

require 'spec_helper'
require 'email/receiver'
require 'jobs/scheduled/poll_mailbox'
require 'email/message_builder'

describe Jobs::PollMailbox do

  describe "processing email" do

    let!(:poller) { Jobs::PollMailbox.new }
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

      before do
        receiver.expects(:process).raises(Email::Receiver::UserNotSufficientTrustLevelError)
        email.expects(:delete)

        Mail::Message.expects(:new).with(email_string).returns(email)

        email.expects(:from)
        email.expects(:body)

        clientMessage = mock
        senderMock = mock
        RejectionMailer.expects(:send_trust_level).returns(clientMessage)
        Email::Sender.expects(:new).with(
          clientMessage, :email_reject_trust_level).returns(senderMock)
        senderMock.expects(:send)
      end

      it "sends a reply and deletes the email" do
        poller.handle_mail(email)
      end
    end

    describe "raises error" do

      it "deletes email on ProcessingError" do
        receiver.expects(:process).raises(Email::Receiver::ProcessingError)
        email.expects(:delete)

        poller.handle_mail(email)
      end

      it "deletes email on EmailUnparsableError" do
        receiver.expects(:process).raises(Email::Receiver::EmailUnparsableError)
        email.expects(:delete)

        poller.handle_mail(email)
      end

      it "deletes email on EmptyEmailError" do
        receiver.expects(:process).raises(Email::Receiver::EmptyEmailError)
        email.expects(:delete)

        poller.handle_mail(email)
      end

      it "deletes email on UserNotFoundError" do
        receiver.expects(:process).raises(Email::Receiver::UserNotFoundError)
        email.expects(:delete)

        poller.handle_mail(email)
      end

      it "deletes email on EmailLogNotFound" do
        receiver.expects(:process).raises(Email::Receiver::EmailLogNotFound)
        email.expects(:delete)

        poller.handle_mail(email)
      end


      it "informs admins on any other error" do
        receiver.expects(:process).raises(TypeError)
        email.expects(:delete)
        GroupMessage.expects(:create) do |args|
          args[0].should eq "admins"
          args[1].shouled eq :email_error_notification
          args[2].message_params.source.should eq email
          args[2].message_params.error.should_be instance_of(TypeError)
        end

        poller.handle_mail(email)
      end
    end
  end

end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Jobs::GroupSmtpEmail do
  let(:post) { Fabricate(:post) }
  let(:group) { Fabricate(:imap_group) }
  let!(:recipient_user) { Fabricate(:user, email: "test@test.com") }
  let(:args) do
    {
      group_id: group.id,
      post_id: post.id,
      email: "test@test.com"
    }
  end

  before do
    SiteSetting.reply_by_email_address = "test+%{reply_key}@incoming.com"
    SiteSetting.manual_polling_enabled = true
    SiteSetting.reply_by_email_enabled = true
    SiteSetting.enable_smtp = true
  end

  it "sends an email using the GroupSmtpMailer and Email::Sender" do
    message = Mail::Message.new(body: "hello", to: "myemail@example.invalid")
    GroupSmtpMailer.expects(:send_mail).with(group, "test@test.com", post).returns(message)
    Email::Sender.expects(:new).with(message, :group_smtp, recipient_user).returns(stub(send: nil))
    subject.execute(args)
  end

  it "creates an IncomingEmail record to avoid double processing via IMAP" do
    subject.execute(args)
    incoming = IncomingEmail.find_by(post_id: post.id, user_id: post.user_id, topic_id: post.topic_id)
    expect(incoming).not_to eq(nil)
    expect(incoming.message_id).to eq("topic/#{post.topic_id}@test.localhost")
  end

  it "creates a PostReplyKey and correctly uses it for the email reply_key substitution" do
    subject.execute(args)
    incoming = IncomingEmail.find_by(post_id: post.id, user_id: post.user_id, topic_id: post.topic_id)
    post_reply_key = PostReplyKey.where(user_id: recipient_user, post_id: post.id).first
    expect(post_reply_key).not_to eq(nil)
    expect(incoming.raw).to include("Reply-To: Discourse <test+#{post_reply_key.reply_key}@incoming.com>")
  end
end

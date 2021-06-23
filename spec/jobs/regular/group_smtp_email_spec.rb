# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Jobs::GroupSmtpEmail do
  fab!(:post) do
    topic = Fabricate(:topic)
    Fabricate(:post, topic: topic)
    Fabricate(:post, topic: topic)
  end
  fab!(:group) { Fabricate(:smtp_group, name: "support-group", full_name: "Support Group") }
  fab!(:recipient_user) { Fabricate(:user, email: "test@test.com") }
  let(:post_id) { post.id }
  let(:args) do
    {
      group_id: group.id,
      post_id: post_id,
      email: "test@test.com",
      cc_emails: ["otherguy@test.com", "cormac@lit.com"]
    }
  end

  before do
    SiteSetting.enable_smtp = true
    SiteSetting.manual_polling_enabled = true
    SiteSetting.reply_by_email_address = "test+%{reply_key}@test.com"
    SiteSetting.reply_by_email_enabled = true
  end

  it "sends an email using the GroupSmtpMailer and Email::Sender" do
    message = Mail::Message.new(body: "hello", to: "myemail@example.invalid")
    GroupSmtpMailer.expects(:send_mail).with(group, "test@test.com", post, ["otherguy@test.com", "cormac@lit.com"]).returns(message)
    subject.execute(args)
  end

  it "creates an EmailLog record with the correct details to avoid double processing via IMAP" do
    subject.execute(args)
    email_log = EmailLog.find_by(post_id: post.id, topic_id: post.topic_id, user_id: recipient_user.id)
    expect(email_log).not_to eq(nil)
    expect(email_log.message_id).to eq("topic/#{post.topic_id}/#{post.id}@test.localhost")
  end

  it "does not create a post reply key, it always replies to the group email_username" do
    subject.execute(args)
    email_log = EmailLog.find_by(post_id: post.id, topic_id: post.topic_id, user_id: recipient_user.id)
    post_reply_key = PostReplyKey.where(user_id: recipient_user, post_id: post.id).first
    expect(post_reply_key).to eq(nil)
    expect(email_log.raw).to include("Reply-To: Support Group via Discourse <#{group.email_username}")
    expect(email_log.raw).to include("From: Support Group via Discourse <#{group.email_username}")
  end

  it "falls back to the group name if full name is blank" do
    group.update(full_name: "")
    subject.execute(args)
    email_log = EmailLog.find_by(post_id: post.id, topic_id: post.topic_id, user_id: recipient_user.id)
    expect(email_log.raw).to include("From: support-group via Discourse <#{group.email_username}")
  end

  it "has the group_smtp_id and the to_address filled in correctly" do
    subject.execute(args)
    email_log = EmailLog.find_by(post_id: post.id, topic_id: post.topic_id, user_id: recipient_user.id)
    expect(email_log.to_address).to eq("test@test.com")
    expect(email_log.smtp_group_id).to eq(group.id)
  end

  context "when there are cc_addresses" do
    let!(:cormac_user) { Fabricate(:user, email: "cormac@lit.com") }

    it "has the cc_addresses and cc_user_ids filled in correctly" do
      subject.execute(args)
      email_log = EmailLog.find_by(post_id: post.id, topic_id: post.topic_id, user_id: recipient_user.id)
      expect(email_log.cc_addresses).to eq("otherguy@test.com;cormac@lit.com")
      expect(email_log.cc_user_ids).to eq([cormac_user.id])
    end
  end

  context "when the post in the argument is the OP" do
    let(:post_id) { post.topic.posts.first.id }
    it "aborts and does not send a group SMTP email; the OP is the one that sent the email in the first place" do
      expect { subject.execute(args) }.not_to(change { EmailLog.count })
    end
  end
end

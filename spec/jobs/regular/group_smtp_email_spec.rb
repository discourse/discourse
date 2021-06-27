# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Jobs::GroupSmtpEmail do
  fab!(:topic) { Fabricate(:private_message_topic, title: "Help I need support") }
  fab!(:post) do
    Fabricate(:post, topic: topic, raw: "some first post content")
    Fabricate(:post, topic: topic, raw: "this is the second post reply")
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
  let(:staged1) { Fabricate(:staged, email: "otherguy@test.com") }
  let(:staged2) { Fabricate(:staged, email: "cormac@lit.com") }
  let(:normaluser) { Fabricate(:user, email: "justanormalguy@test.com", username: "normaluser") }

  before do
    SiteSetting.enable_smtp = true
    SiteSetting.manual_polling_enabled = true
    SiteSetting.reply_by_email_address = "test+%{reply_key}@test.com"
    SiteSetting.reply_by_email_enabled = true
    TopicAllowedGroup.create(group: group, topic: topic)
    TopicAllowedUser.create(user: staged1, topic: topic)
    TopicAllowedUser.create(user: staged2, topic: topic)
    TopicAllowedUser.create(user: normaluser, topic: topic)
  end

  it "sends an email using the GroupSmtpMailer and Email::Sender" do
    message = Mail::Message.new(body: "hello", to: "myemail@example.invalid")
    GroupSmtpMailer.expects(:send_mail).with(group, "test@test.com", post, ["otherguy@test.com", "cormac@lit.com"]).returns(message)
    subject.execute(args)
  end

  it "includes a 'reply above this line' message" do
    subject.execute(args)
    email_log = EmailLog.find_by(post_id: post.id, topic_id: post.topic_id, user_id: recipient_user.id)
    expect(email_log.raw_body).to include(I18n.t("user_notifications.reply_above_line"))
  end

  it "does not include context posts" do
    subject.execute(args)
    email_log = EmailLog.find_by(post_id: post.id, topic_id: post.topic_id, user_id: recipient_user.id)
    expect(email_log.raw_body).not_to include(I18n.t("user_notifications.previous_discussion"))
    expect(email_log.raw_body).not_to include("some first post content")
  end

  it "includes the participants in the correct format" do
    subject.execute(args)
    email_log = EmailLog.find_by(post_id: post.id, topic_id: post.topic_id, user_id: recipient_user.id)
    expect(email_log.raw_body).to include("Support Group")
    expect(email_log.raw_body).to include("otherguy@test.com")
    expect(email_log.raw_body).to include("cormac@lit.com")
    expect(email_log.raw_body).to include("normaluser")
  end

  it "creates an EmailLog record with the correct details" do
    subject.execute(args)
    email_log = EmailLog.find_by(post_id: post.id, topic_id: post.topic_id, user_id: recipient_user.id)
    expect(email_log).not_to eq(nil)
    expect(email_log.message_id).to eq("topic/#{post.topic_id}/#{post.id}@test.localhost")
  end

  it "creates an IncomingEmail record with the correct details to avoid double processing IMAP" do
    subject.execute(args)
    incoming_email = IncomingEmail.find_by(post_id: post.id, topic_id: post.topic_id, user_id: post.user.id)
    expect(incoming_email).not_to eq(nil)
    expect(incoming_email.message_id).to eq("topic/#{post.topic_id}/#{post.id}@test.localhost")
    expect(incoming_email.created_via).to eq(IncomingEmail.created_via_types[:group_smtp])
    expect(incoming_email.to_addresses).to eq("test@test.com")
    expect(incoming_email.cc_addresses).to eq("otherguy@test.com;cormac@lit.com")
    expect(incoming_email.subject).to eq("Re: Help I need support")
  end

  it "does not create a post reply key, it always replies to the group email_username" do
    subject.execute(args)
    email_log = EmailLog.find_by(post_id: post.id, topic_id: post.topic_id, user_id: recipient_user.id)
    post_reply_key = PostReplyKey.where(user_id: recipient_user, post_id: post.id).first
    expect(post_reply_key).to eq(nil)
    expect(email_log.raw_headers).not_to include("Reply-To: Support Group via Discourse <#{group.email_username}")
    expect(email_log.raw_headers).to include("From: Support Group via Discourse <#{group.email_username}")
  end

  it "creates an EmailLog record with the correct details" do
    subject.execute(args)
    email_log = EmailLog.find_by(post_id: post.id, topic_id: post.topic_id, user_id: recipient_user.id)
    expect(email_log).not_to eq(nil)
    expect(email_log.message_id).to eq("topic/#{post.topic_id}/#{post.id}@test.localhost")
  end

  it "creates an IncomingEmail record with the correct details to avoid double processing IMAP" do
    subject.execute(args)
    incoming_email = IncomingEmail.find_by(post_id: post.id, topic_id: post.topic_id, user_id: post.user.id)
    expect(incoming_email).not_to eq(nil)
    expect(incoming_email.message_id).to eq("topic/#{post.topic_id}/#{post.id}@test.localhost")
    expect(incoming_email.created_via).to eq(IncomingEmail.created_via_types[:group_smtp])
    expect(incoming_email.to_addresses).to eq("test@test.com")
    expect(incoming_email.cc_addresses).to eq("otherguy@test.com;cormac@lit.com")
    expect(incoming_email.subject).to eq("Re: Help I need support")
  end

  it "does not create a post reply key, it always replies to the group email_username" do
    subject.execute(args)
    email_log = EmailLog.find_by(post_id: post.id, topic_id: post.topic_id, user_id: recipient_user.id)
    post_reply_key = PostReplyKey.where(user_id: recipient_user, post_id: post.id).first
    expect(post_reply_key).to eq(nil)
    expect(email_log.raw).not_to include("Reply-To: Support Group via Discourse <#{group.email_username}")
    expect(email_log.raw).to include("From: Support Group via Discourse <#{group.email_username}")
  end

  it "falls back to the group name if full name is blank" do
    group.update(full_name: "")
    subject.execute(args)
    email_log = EmailLog.find_by(post_id: post.id, topic_id: post.topic_id, user_id: recipient_user.id)
    expect(email_log.raw_headers).to include("From: support-group via Discourse <#{group.email_username}")
  end

  it "has the group_smtp_id and the to_address filled in correctly" do
    subject.execute(args)
    email_log = EmailLog.find_by(post_id: post.id, topic_id: post.topic_id, user_id: recipient_user.id)
    expect(email_log.to_address).to eq("test@test.com")
    expect(email_log.smtp_group_id).to eq(group.id)
  end

  context "when there are cc_addresses" do
    it "has the cc_addresses and cc_user_ids filled in correctly" do
      subject.execute(args)
      email_log = EmailLog.find_by(post_id: post.id, topic_id: post.topic_id, user_id: recipient_user.id)
      expect(email_log.cc_addresses).to eq("otherguy@test.com;cormac@lit.com")
      expect(email_log.cc_user_ids).to match_array([staged1.id, staged2.id])
    end
  end

  context "when the post in the argument is the OP" do
    let(:post_id) { post.topic.posts.first.id }
    it "aborts and does not send a group SMTP email; the OP is the one that sent the email in the first place" do
      expect { subject.execute(args) }.not_to(change { EmailLog.count })
    end
  end
end

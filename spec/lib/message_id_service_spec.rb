# frozen_string_literal: true

require 'rails_helper'

describe Email::MessageIdService do
  fab!(:topic) { Fabricate(:topic) }
  fab!(:post) { Fabricate(:post, topic: topic) }
  fab!(:second_post) { Fabricate(:post, topic: topic) }

  subject { described_class }

  describe "#generate_for_post" do
    it "generates for the post using the message_id on the post's incoming_email" do
      Fabricate(:incoming_email, message_id: "test@test.localhost", post: post)
      post.reload
      expect(subject.generate_for_post(post, use_incoming_email_if_present: true)).to eq("<test@test.localhost>")
    end

    it "generates for the post without an incoming_email record" do
      expect(subject.generate_for_post(post)).to match(subject.message_id_post_id_regexp)
      expect(subject.generate_for_post(post, use_incoming_email_if_present: true)).to match(subject.message_id_post_id_regexp)
    end
  end

  describe "#generate_for_topic" do
    it "generates for the topic using the message_id on the first post's incoming_email" do
      Fabricate(:incoming_email, message_id: "test@test.localhost", post: post)
      post.reload
      expect(subject.generate_for_topic(topic, use_incoming_email_if_present: true)).to eq("<test@test.localhost>")
    end

    it "generates for the topic without an incoming_email record" do
      expect(subject.generate_for_topic(topic)).to match(subject.message_id_topic_id_regexp)
      expect(subject.generate_for_topic(topic, use_incoming_email_if_present: true)).to match(subject.message_id_topic_id_regexp)
    end
  end

  describe "find_post_from_message_ids" do
    let(:post_format_message_id) { "<topic/#{topic.id}/#{post.id}.test123@test.localhost>" }
    let(:topic_format_message_id) { "<topic/#{topic.id}.test123@test.localhost>" }
    let(:default_format_message_id) { "<36ac1ddd-5083-461d-b72c-6372fb0e7f33@test.localhost>" }
    let(:gmail_format_message_id) { "<CAPGrNgZ7QEFuPcsxJBRZLhBhAYPO_ruYpCANSdqiQEbc9Otpiw@mail.gmail.com>" }

    it "finds a post based only on a post-format message id" do
      expect(subject.find_post_from_message_ids([post_format_message_id])).to eq(post)
    end

    it "finds a post based only on a topic-format message id" do
      expect(subject.find_post_from_message_ids([topic_format_message_id])).to eq(post)
    end

    it "finds a post from the email log" do
      email_log = Fabricate(:email_log, message_id: subject.message_id_clean(default_format_message_id))
      expect(subject.find_post_from_message_ids([default_format_message_id])).to eq(email_log.post)
    end

    it "finds a post from the incoming email log" do
      incoming_email = Fabricate(
        :incoming_email,
        message_id: subject.message_id_clean(gmail_format_message_id),
        post: Fabricate(:post)
      )
      expect(subject.find_post_from_message_ids([gmail_format_message_id])).to eq(incoming_email.post)
    end

    it "gets the last created post if multiple are returned" do
      incoming_email = Fabricate(
        :incoming_email,
        message_id: subject.message_id_clean(post_format_message_id),
        post: Fabricate(:post, created_at: 10.days.ago)
      )
      expect(subject.find_post_from_message_ids([post_format_message_id])).to eq(post)
    end
  end

  describe "#discourse_generated_message_id?" do
    def check_format(message_id)
      subject.discourse_generated_message_id?(message_id)
    end

    it "works correctly for the different possible formats" do
      expect(check_format("topic/1223/4525.3c4f8n9@test.localhost")).to eq(true)
      expect(check_format("<topic/1223/4525.3c4f8n9@test.localhost>")).to eq(true)
      expect(check_format("topic/1223.fc3j4843@test.localhost")).to eq(true)
      expect(check_format("<topic/1223.fc3j4843@test.localhost>")).to eq(true)
      expect(check_format("topic/1223/4525@test.localhost")).to eq(true)
      expect(check_format("<topic/1223/4525@test.localhost>")).to eq(true)
      expect(check_format("topic/1223@test.localhost")).to eq(true)
      expect(check_format("<topic/1223@test.localhost>")).to eq(true)

      expect(check_format("topic/1223@blah")).to eq(false)
      expect(check_format("<CAPGrNgZ7QEFuPcsxJBRZLhBhAYPO_ruYpCANSdqiQEbc9Otpiw@mail.gmail.com>")).to eq(false)
      expect(check_format("t/1223@test.localhost")).to eq(false)
    end
  end

  describe "#message_id_rfc_format" do
    it "returns message ID in RFC format" do
      expect(Email::MessageIdService.message_id_rfc_format("test@test")).to eq("<test@test>")
    end

    it "returns input if already in RFC format" do
      expect(Email::MessageIdService.message_id_rfc_format("<test@test>")).to eq("<test@test>")
    end
  end

  describe "#message_id_clean" do
    it "returns message ID if in RFC format" do
      expect(Email::MessageIdService.message_id_clean("<test@test>")).to eq("test@test")
    end

    it "returns input if a clean message ID is not in RFC format" do
      message_id = "<" + "@" * 50
      expect(Email::MessageIdService.message_id_clean(message_id)).to eq(message_id)
    end
  end
end

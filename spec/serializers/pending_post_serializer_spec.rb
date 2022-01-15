# frozen_string_literal: true

require "rails_helper"

RSpec.describe PendingPostSerializer do
  subject(:serializer) { described_class.new(post, scope: guardian, root: false) }

  let(:guardian) { Guardian.new(author) }
  let(:author) { post.created_by }

  before { freeze_time }

  context "when creating a new topic" do
    let(:post) { Fabricate(:reviewable_queued_post_topic) }
    let(:expected_attributes) do
      {
        id: post.id,
        avatar_template: author.avatar_template,
        category_id: post.category_id,
        created_at: Time.current,
        created_by_id: author.id,
        name: author.name,
        raw_text: post.payload["raw"],
        title: post.payload["title"],
        topic_id: nil,
        topic_url: nil,
        username: author.username
      }
    end

    it "serializes a pending post properly" do
      expect(serializer.as_json).to match expected_attributes
    end
  end

  context "when not creating a new topic" do
    let(:post) { Fabricate(:reviewable_queued_post) }
    let(:topic) { post.topic }
    let(:expected_attributes) do
      {
        id: post.id,
        avatar_template: author.avatar_template,
        category_id: post.category_id,
        created_at: Time.current,
        created_by_id: author.id,
        name: author.name,
        raw_text: post.payload["raw"],
        title: topic.title,
        topic_id: topic.id,
        topic_url: topic.url,
        username: author.username
      }
    end

    it "serializes a pending post properly" do
      expect(serializer.as_json).to match expected_attributes
    end
  end
end

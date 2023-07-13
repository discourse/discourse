# frozen_string_literal: true

describe BasicReviewableFlaggedPostSerializer do
  subject(:serializer) { described_class.new(reviewable, root: false).as_json }

  fab!(:topic) { Fabricate(:topic, title: "safe title <a> hello world") }
  fab!(:post) { Fabricate(:post, topic: topic) }

  fab!(:reviewable) do
    ReviewableFlaggedPost.needs_review!(
      target: post,
      topic: topic,
      created_by: Discourse.system_user,
    )
  end

  include_examples "basic reviewable attributes"

  describe "#post_number" do
    it "equals the post_number of the post" do
      expect(serializer[:post_number]).to eq(post.post_number)
    end

    it "is not included if the reviewable is associated with no post" do
      reviewable.update!(target: nil)
      expect(serializer.key?(:post_number)).to eq(false)
    end
  end

  describe "#topic_fancy_title" do
    it "equals the fancy_title of the topic" do
      expect(serializer[:topic_fancy_title]).to eq("Safe title &lt;a&gt; hello world")
    end

    it "is not included if the reviewable is associated with no topic" do
      reviewable.update!(topic: nil)
      expect(serializer.key?(:topic_fancy_title)).to eq(false)
    end
  end
end

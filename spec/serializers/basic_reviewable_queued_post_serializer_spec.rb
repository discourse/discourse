# frozen_string_literal: true

describe BasicReviewableQueuedPostSerializer do
  subject(:serializer) { described_class.new(reviewable, root: false).as_json }

  fab!(:topic) { Fabricate(:topic, title: "safe title <a> existing topic") }
  fab!(:reviewable) do
    ReviewableQueuedPost.create!(
      created_by: Discourse.system_user,
      topic_id: topic.id,
      payload: {
        raw: "new post 123",
        title: "unsafe title <a>",
      },
    )
  end

  include_examples "basic reviewable attributes"

  describe "#topic_fancy_title" do
    it "equals the topic's fancy_title" do
      expect(serializer[:topic_fancy_title]).to eq("Safe title &lt;a&gt; existing topic")
    end

    it "is not included if the reviewable is associated with no topic" do
      reviewable.update!(topic: nil)
      expect(serializer.key?(:topic_fancy_title)).to eq(false)
    end
  end

  describe "#is_new_topic" do
    it "is true if the reviewable's payload has a title attribute" do
      expect(serializer[:is_new_topic]).to eq(true)
    end

    it "is false if the reviewable's payload doesn't have a title attribute" do
      reviewable.update!(payload: { raw: "new post 123" })
      expect(serializer[:is_new_topic]).to eq(false)
    end
  end

  describe "#payload_title" do
    it "equals the title in the reviewable's payload" do
      expect(serializer[:payload_title]).to eq("unsafe title <a>")
    end

    it "is not included if the reviewable's payload doesn't have a title attribute" do
      reviewable.update!(payload: { raw: "new post 123" })
      expect(serializer.key?(:payload_title)).to eq(false)
    end
  end
end

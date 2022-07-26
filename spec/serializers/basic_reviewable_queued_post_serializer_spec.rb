# frozen_string_literal: true

describe BasicReviewableQueuedPostSerializer do
  fab!(:topic) { Fabricate(:topic, title: "safe title <a> existing topic") }
  fab!(:reviewable) do
    ReviewableQueuedPost.create!(
      created_by: Discourse.system_user,
      topic_id: topic.id,
      payload: { raw: "new post 123", title: "unsafe title <a>" }
    )
  end

  subject { described_class.new(reviewable, root: false).as_json }

  include_examples "basic reviewable attributes"

  context "#topic_title" do
    it "equals the topic's fancy_title" do
      expect(subject[:topic_title]).to eq("Safe title &lt;a&gt; existing topic")
    end

    it "falls back the title in payload if the reviewable is associated with no topic" do
      reviewable.update!(topic: nil)
      expect(subject[:topic_title]).to eq("unsafe title <a>")
    end
  end
end

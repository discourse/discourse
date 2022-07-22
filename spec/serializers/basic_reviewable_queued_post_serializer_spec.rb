# frozen_string_literal: true

describe BasicReviewableQueuedPostSerializer do
  def get_json
    described_class.new(reviewable, root: false).as_json
  end

  context "when the queud post is a new topic" do
    fab!(:reviewable) do
      ReviewableQueuedPost.create!(
        created_by: Discourse.system_user,
        payload: {
          raw: "new topic 123",
          title: "unsafe title <a>"
        }
      )
    end

    it "sets topic_title to the title of the queued topic" do
      expect(get_json[:topic_title]).to eq("unsafe title <a>")
    end

    it "sets is_new_topic to true" do
      expect(get_json[:is_new_topic]).to eq(true)
    end
  end

  context "when the queud post is in an existing topic" do
    fab!(:topic) { Fabricate(:topic, title: "unsafe title <a> existing topic") }

    fab!(:reviewable) do
      ReviewableQueuedPost.create!(
        created_by: Discourse.system_user,
        topic_id: topic.id,
        payload: { raw: "new post 123" }
      )
    end

    it "sets topic_title to the title of the existing topic" do
      expect(get_json[:topic_title]).to eq("Unsafe title &lt;a&gt; existing topic")
    end

    it "sets is_new_topic to false" do
      expect(get_json[:is_new_topic]).to eq(false)
    end
  end

  it "is a subclass of BasicReviewableSerializer" do
    expect(described_class).to be < BasicReviewableSerializer
  end
end

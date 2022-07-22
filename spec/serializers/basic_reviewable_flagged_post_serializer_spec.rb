# frozen_string_literal: true

describe BasicReviewableFlaggedPostSerializer do
  fab!(:topic) { Fabricate(:topic, title: "unsafe title <a>") }
  fab!(:post) { Fabricate(:post, topic: topic) }

  fab!(:reviewable) do
    ReviewableFlaggedPost.needs_review!(target: post, topic: topic, created_by: Discourse.system_user)
  end

  def get_json
    described_class.new(reviewable, root: false).as_json
  end

  it "includes post_number of the flagged post" do
    expect(get_json[:post_number]).to eq(post.post_number)
  end

  it "includes topic_title of the flagged post" do
    expect(get_json[:topic_title]).to eq("Unsafe title &lt;a&gt;")
  end

  it "is a subclass of BasicReviewableSerializer" do
    expect(described_class).to be < BasicReviewableSerializer
  end
end

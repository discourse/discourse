# frozen_string_literal: true

RSpec.describe Blog::ReviewSerializer do
  subject(:json) { described_class.new(review, root: false, **options).as_json }

  include_context "with a reviewable blog draft"

  let(:review) { issue_blog_review(topic, user: admin, label: "Round one") }
  let(:options) { { active_review_ids: [review.id] } }

  it "serializes the link for editors" do
    expect(json).to eq(
      id: review.id,
      label: "Round one",
      title: review.title,
      post_version: review.post_version,
      created_at: review.created_at,
      expires_at: review.expires_at,
      revoked_at: nil,
      revoked_by_publish: false,
      active: true,
      url: review.url,
    )
  end

  context "when the link is inactive" do
    let(:options) { { active_review_ids: [] } }

    it "hides its URL" do
      expect(json).to include(active: false, url: nil)
    end
  end

  context "with feedback counts" do
    let(:options) { super().merge(feedback_counts: { review.id => 3 }) }

    it "includes the link's count" do
      expect(json[:feedback_count]).to eq(3)
    end

    it "defaults to zero for a link without feedback" do
      options[:feedback_counts].clear

      expect(json[:feedback_count]).to eq(0)
    end
  end
end

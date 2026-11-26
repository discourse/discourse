# frozen_string_literal: true

RSpec.describe Blog::ReviewFeedbackSerializer do
  subject(:json) { described_class.new(review_feedback, root: false, **options).as_json }

  include_context "with a reviewable blog draft"

  let(:review) { issue_blog_review(topic, user: admin, label: "Round one") }
  let(:review_feedback) do
    submit_blog_review_feedback(review, name: "Ada", email: "ada@example.com", message: "Nice")
  end
  let(:options) { {} }

  it "serializes the response without its link" do
    expect(json).to eq(
      id: review_feedback.id,
      name: "Ada",
      email: "ada@example.com",
      message: "Nice",
      created_at: review_feedback.created_at,
    )
  end

  context "when the link is requested" do
    let(:options) { { include_review: true } }

    it "includes a summary of the link" do
      expect(json[:review]).to eq(
        id: review.id,
        label: "Round one",
        post_version: review.post_version,
        revoked_at: nil,
      )
    end
  end
end

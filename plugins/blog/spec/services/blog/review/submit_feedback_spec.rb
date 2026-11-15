# frozen_string_literal: true

RSpec.describe Blog::Review::SubmitFeedback do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:review_id) }
    it { is_expected.to validate_presence_of(:feedback) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    include_context "with a reviewable blog draft"

    let!(:review) { issue_blog_review(topic, user: admin) }
    let(:params) do
      {
        review_id: review.id,
        feedback: {
          name: " Reviewer ",
          email: "reviewer@example.com",
          message: "Please tighten the ending.",
        },
      }
    end
    let(:dependencies) { { guardian: Guardian.new } }

    context "when contract is invalid" do
      let(:params) { { review_id: review.id } }

      it { is_expected.to fail_a_contract }
    end

    context "when the link does not exist" do
      let(:params) { super().merge(review_id: 0) }

      it { is_expected.to fail_to_find_a_model(:review) }
    end

    context "when the draft has been deleted" do
      before { topic.update_columns(deleted_at: Time.current) }

      it { is_expected.to fail_to_find_a_model(:topic) }
    end

    context "when the link is no longer accessible" do
      before { review.update!(revoked_at: Time.current) }

      it { is_expected.to fail_a_policy(:review_is_accessible) }
    end

    context "when the link has received the maximum amount of feedback" do
      around { |example| stub_const(Blog::Review, :MAX_FEEDBACK, 1) { example.run } }

      before { submit_blog_review_feedback(review, message: "First") }

      it { is_expected.to fail_a_policy(:within_feedback_limit) }
    end

    context "when the feedback is invalid" do
      let(:params) { super().deep_merge(feedback: { message: "" }) }

      it { is_expected.to fail_with_an_invalid_model(:review_feedback) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "stores the feedback privately on the link" do
        expect(result.review_feedback).to have_attributes(
          review:,
          name: "Reviewer",
          email: "reviewer@example.com",
          message: "Please tighten the ending.",
        )
        expect(topic.posts.count).to eq(1)
      end
    end
  end
end

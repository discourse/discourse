# frozen_string_literal: true

RSpec.describe Blog::Review::Create do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:topic_id) }

    it "treats a missing label as blank" do
      contract = described_class.new(topic_id: 1, label: nil)

      expect(contract).to be_valid
      expect(contract.label).to eq("")
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    include_context "with a reviewable blog draft"

    fab!(:acting_user, :admin)

    let(:params) { { topic_id: topic.id, label: "Editorial round" } }
    let(:dependencies) { { guardian: acting_user.guardian } }

    context "when contract is invalid" do
      let(:params) { { label: "Editorial round" } }

      it { is_expected.to fail_a_contract }
    end

    context "when the topic does not exist" do
      let(:params) { super().merge(topic_id: 0) }

      it { is_expected.to fail_to_find_a_model(:topic) }
    end

    context "when the user cannot edit the draft" do
      fab!(:acting_user, :user)

      it { is_expected.to fail_a_policy(:can_edit_blog_topic) }
    end

    context "when the blog is not ready" do
      before { SiteSetting.prevent_anons_from_downloading_files = true }

      it { is_expected.to fail_a_policy(:blog_is_ready) }
    end

    context "when the draft cannot be reviewed" do
      before { first_post.update_columns(hidden: true) }

      it { is_expected.to fail_a_policy(:topic_is_reviewable) }
    end

    context "when the draft already has the maximum number of open links" do
      around { |example| stub_const(Blog::Review, :MAX_ACTIVE_PER_TOPIC, 1) { example.run } }

      before { issue_blog_review(topic, user: admin) }

      it { is_expected.to fail_a_policy(:within_review_limit) }
    end

    context "when the snapshot is too large" do
      around { |example| stub_const(Blog::Review, :MAX_SNAPSHOT_BYTES, 1) { example.run } }

      it { is_expected.to fail_a_policy(:snapshot_within_size_limit) }
    end

    context "when the label is too long" do
      let(:params) { super().merge(label: "x" * 101) }

      it { is_expected.to fail_with_an_invalid_model(:review) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "issues a link to a frozen snapshot of the draft" do
        expect(result.review).to have_attributes(
          topic:,
          creator: acting_user,
          label: "Editorial round",
          title: topic.title,
          post_version: first_post.version,
          token: match(Blog::Review::TOKEN_FORMAT),
          expires_at: be_within(1.minute).of(Blog::Review::LIFETIME.from_now),
        )
        expect(result.review.cooked).to include(first_post.cooked)
      end

      it "logs the creation" do
        expect { result }.to change {
          UserHistory.where(acting_user_id: acting_user.id, custom_type: "blog_review_create").count
        }.by(1)
      end
    end
  end
end

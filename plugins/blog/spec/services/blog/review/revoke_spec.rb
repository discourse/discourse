# frozen_string_literal: true

RSpec.describe Blog::Review::Revoke do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:topic_id) }
    it { is_expected.to validate_presence_of(:review_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    include_context "with a reviewable blog draft"

    fab!(:acting_user, :admin)

    let!(:review) { issue_blog_review(topic, user: admin) }
    let(:params) { { topic_id: topic.id, review_id: review.id } }
    let(:dependencies) { { guardian: acting_user.guardian } }

    context "when contract is invalid" do
      let(:params) { { topic_id: topic.id } }

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

    context "when the link belongs to another draft" do
      let(:params) do
        other_topic = Fabricate(:topic, category: drafts, user: admin)
        super().merge(topic_id: other_topic.id)
      end

      it { is_expected.to fail_to_find_a_model(:review) }
    end

    context "when the link is already revoked" do
      before { review.update!(revoked_at: 1.day.ago) }

      it { is_expected.to run_successfully }

      it "keeps the original revocation time" do
        expect { result }.not_to change { review.reload.revoked_at }
      end
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "closes the link" do
        expect { result }.to change { review.reload.revoked_at }.from(nil).to(be_present)
      end

      it "logs the revocation" do
        expect { result }.to change {
          UserHistory.where(acting_user_id: acting_user.id, custom_type: "blog_review_revoke").count
        }.by(1)
      end
    end
  end
end

# frozen_string_literal: true

RSpec.describe PostRevision::Relist do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:post_id) }
    it { is_expected.to validate_presence_of(:revision) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:acting_user, :moderator)
    fab!(:post)
    fab!(:post_revision) { Fabricate(:post_revision, post:, unlisted: true) }

    let(:params) { { post_id:, revision: } }
    let(:dependencies) { { guardian: } }
    let(:guardian) { acting_user.guardian }
    let(:post_id) { post.id }
    let(:revision) { post_revision.number }

    context "when contract is invalid" do
      let(:revision) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when post is not found" do
      let(:post_id) { 0 }

      it { is_expected.to fail_to_find_a_model(:post) }
    end

    context "when acting user cannot see the post" do
      fab!(:private_message_post)

      let(:post_id) { private_message_post.id }

      it { is_expected.to fail_a_policy(:can_see_post) }
    end

    context "when post is deleted" do
      before { post.trash! }

      it { is_expected.to run_successfully }
    end

    context "when topic is deleted" do
      before { post.topic.trash! }

      it { is_expected.to run_successfully }
    end

    context "when post revision is not found" do
      let(:revision) { post_revision.number + 1 }

      it { is_expected.to fail_to_find_a_model(:post_revision) }
    end

    context "when acting user cannot relist the post revision" do
      fab!(:acting_user, :user)

      it { is_expected.to fail_a_policy(:can_relist_post_revision) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "relists the post revision" do
        expect { result }.to change { post_revision.reload.unlisted }.from(true).to(false)
      end
    end
  end
end

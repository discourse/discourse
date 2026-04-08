# frozen_string_literal: true

RSpec.describe NestedTopic::TogglePin do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:topic_id) }
    it { is_expected.to validate_presence_of(:post_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:topic)
    fab!(:post) { Fabricate(:post, topic: topic, post_number: 1) }

    let(:params) { { topic_id: topic.id, post_id: post.id } }
    let(:dependencies) { { guardian: admin.guardian } }

    context "when contract is invalid" do
      let(:params) { { topic_id: nil, post_id: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when topic is not found" do
      let(:params) { { topic_id: 0, post_id: post.id } }

      it { is_expected.to fail_to_find_a_model(:topic) }
    end

    context "when post is not found" do
      let(:params) { { topic_id: topic.id, post_id: 0 } }

      it { is_expected.to fail_to_find_a_model(:post) }
    end

    context "when user is not staff" do
      fab!(:admin, :user)

      it { is_expected.to fail_a_policy(:staff_can_edit) }
    end

    context "when post is not a root post" do
      fab!(:post) { Fabricate(:post, topic: topic, reply_to_post_number: 2) }

      it { is_expected.to fail_a_policy(:post_is_root) }
    end

    context "when pin limit is reached" do
      before do
        Fabricate(:nested_topic, topic: topic).update!(
          pinned_post_ids: Array.new(NestedTopic::MAX_PINNED_POSTS) { |i| i + 1000 },
        )
      end

      it { is_expected.to fail_a_policy(:within_pin_limit) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "pins the post" do
        result
        nested = topic.nested_topic.reload
        expect(nested.pinned_post_ids).to include(post.id)
      end

      context "when post is already pinned" do
        before { Fabricate(:nested_topic, topic: topic, pinned_post_ids: [post.id]) }

        it { is_expected.to run_successfully }

        it "unpins the post" do
          result
          nested = topic.nested_topic.reload
          expect(nested.pinned_post_ids).not_to include(post.id)
        end
      end

      context "when post replies to the OP" do
        fab!(:post) { Fabricate(:post, topic: topic, reply_to_post_number: 1) }

        it { is_expected.to run_successfully }
      end

      context "when pin limit is reached but post is already pinned" do
        before do
          Fabricate(:nested_topic, topic: topic).update!(
            pinned_post_ids: [post.id] + Array.new(9) { |i| i + 1000 },
          )
        end

        it { is_expected.to run_successfully }

        it "unpins the post" do
          result
          nested = topic.nested_topic.reload
          expect(nested.pinned_post_ids).not_to include(post.id)
        end
      end
    end
  end
end

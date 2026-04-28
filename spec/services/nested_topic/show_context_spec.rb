# frozen_string_literal: true

RSpec.describe NestedTopic::ShowContext do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:target_post_number) }
    it { is_expected.to validate_presence_of(:sort) }
    it { is_expected.to allow_value(nil).for(:context_depth) }
    it { is_expected.to allow_value(0).for(:context_depth) }
    it { is_expected.to allow_value(100).for(:context_depth) }
    it { is_expected.not_to allow_value(101).for(:context_depth) }
    it { is_expected.not_to allow_value(-1).for(:context_depth) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
    fab!(:topic) { Fabricate(:topic, user: user) }
    fab!(:op) { Fabricate(:post, topic: topic, user: user, post_number: 1) }
    fab!(:target) { Fabricate(:post, topic: topic, user: user, reply_to_post_number: 1) }

    let(:topic_view) do
      TopicView.new(topic.id, user, skip_custom_fields: true, skip_post_loading: true)
    end
    let(:dependencies) { { guardian: user.guardian, topic_view: topic_view } }
    let(:params) { { target_post_number: target.post_number, sort: "top" } }

    before { SiteSetting.nested_replies_enabled = true }

    context "when contract is invalid" do
      let(:params) { { target_post_number: nil, sort: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when target post is not found" do
      let(:params) { { target_post_number: 99_999, sort: "top" } }

      it { is_expected.to fail_to_find_a_model(:target_post) }
    end

    context "when target post has an invisible post type" do
      before { target.update!(post_type: Post.types[:whisper]) }

      it { is_expected.to fail_to_find_a_model(:target_post) }
    end

    context "when target post is soft-deleted" do
      before { PostDestroyer.new(Discourse.system_user, target, context: "spec").destroy }

      it { is_expected.to run_successfully }

      it "resolves the deleted post and serializes it via the placeholder path" do
        response = result[:response]
        expect(response[:target_post][:id]).to eq(target.id)
        expect(response[:target_post][:deleted_post_placeholder]).to eq(true)
      end
    end

    context "when target is a root post" do
      it { is_expected.to run_successfully }

      it "returns response with empty ancestor chain" do
        response = result[:response]
        expect(response[:topic]).to be_present
        expect(response[:op_post]).to be_present
        expect(response[:ancestor_chain]).to be_empty
        expect(response[:ancestors_truncated]).to eq(false)
        expect(response[:siblings]).to be_a(Hash)
        expect(response[:target_post][:id]).to eq(target.id)
        expect(response[:message_bus_last_id]).to be_an(Integer)
      end
    end

    context "with context_depth set to 0" do
      let(:params) { { target_post_number: target.post_number, sort: "top", context_depth: 0 } }

      it { is_expected.to run_successfully }

      it "returns an empty ancestor chain" do
        expect(result[:response][:ancestor_chain]).to be_empty
      end
    end

    context "when target has ancestors" do
      fab!(:ancestor_post) { Fabricate(:post, topic: topic, user: user, reply_to_post_number: 1) }
      fab!(:target) do
        Fabricate(:post, topic: topic, user: user, reply_to_post_number: ancestor_post.post_number)
      end

      it { is_expected.to run_successfully }

      it "populates the ancestor chain" do
        response = result[:response]
        expect(response[:ancestor_chain]).to be_present
        ancestor_numbers = response[:ancestor_chain].map { |a| a[:post_number] }
        expect(ancestor_numbers).to include(ancestor_post.post_number)
      end

      it "populates siblings for ancestors" do
        response = result[:response]
        expect(response[:siblings]).to be_a(Hash)
      end
    end
  end
end

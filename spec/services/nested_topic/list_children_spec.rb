# frozen_string_literal: true

RSpec.describe NestedTopic::ListChildren do
  describe described_class::Contract, type: :model do
    subject { described_class.new(parent_post_number: 2, sort: "top", page: 0, depth: 1) }

    it { is_expected.to validate_presence_of(:parent_post_number) }
    it { is_expected.to validate_presence_of(:sort) }
    it { is_expected.to validate_presence_of(:page) }
    it { is_expected.to validate_presence_of(:depth) }
    it { is_expected.not_to allow_value(-1).for(:page) }
    it { is_expected.not_to allow_value(0).for(:depth) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
    fab!(:topic) { Fabricate(:topic, user: user) }
    fab!(:op) { Fabricate(:post, topic: topic, user: user, post_number: 1) }
    fab!(:parent_post) { Fabricate(:post, topic: topic, user: user, reply_to_post_number: 1) }

    let(:topic_view) do
      TopicView.new(topic.id, user, skip_custom_fields: true, skip_post_loading: true)
    end
    let(:dependencies) { { guardian: user.guardian, topic_view: topic_view } }
    let(:params) { { parent_post_number: parent_post.post_number, sort: "top", page: 0, depth: 1 } }

    before { SiteSetting.nested_replies_enabled = true }

    context "when contract is invalid" do
      let(:params) { { parent_post_number: nil, sort: nil, page: nil, depth: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when there are no children" do
      it { is_expected.to run_successfully }

      it "returns an empty children list" do
        response = result[:response]
        expect(response[:children]).to be_empty
        expect(response[:has_more]).to eq(false)
        expect(response[:page]).to eq(0)
      end
    end

    context "when there are children" do
      fab!(:child_post) do
        Fabricate(:post, topic: topic, user: user, reply_to_post_number: parent_post.post_number)
      end

      it { is_expected.to run_successfully }

      it "returns children with nested tree structure" do
        response = result[:response]
        expect(response[:children]).to be_present
        expect(response[:children].first[:id]).to eq(child_post.id)
        expect(response[:children].first).to have_key(:children)
      end
    end

    context "when in flattened mode" do
      fab!(:child_post) do
        Fabricate(:post, topic: topic, user: user, reply_to_post_number: parent_post.post_number)
      end

      before do
        SiteSetting.nested_replies_cap_nesting_depth = true
        SiteSetting.nested_replies_max_depth = 1
      end

      let(:params) do
        { parent_post_number: parent_post.post_number, sort: "top", page: 0, depth: 1 }
      end

      it { is_expected.to run_successfully }

      it "returns children with empty children arrays" do
        response = result[:response]
        expect(response[:children]).to be_present
        response[:children].each { |child| expect(child[:children]).to eq([]) }
      end
    end
  end
end

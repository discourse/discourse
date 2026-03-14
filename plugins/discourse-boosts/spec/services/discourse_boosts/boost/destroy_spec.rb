# frozen_string_literal: true

RSpec.describe DiscourseBoosts::Boost::Destroy do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:boost_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:acting_user, :user)
    fab!(:post_author, :user)
    fab!(:category)
    fab!(:topic) { Fabricate(:topic, category: category) }
    fab!(:post) { Fabricate(:post, topic: topic, user: post_author) }
    fab!(:boost) { Fabricate(:boost, post: post, user: acting_user) }

    let(:params) { { boost_id: boost.id } }
    let(:dependencies) { { guardian: acting_user.guardian } }

    context "when contract is invalid" do
      let(:params) { { boost_id: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when boost is not found" do
      let(:params) { { boost_id: 0 } }

      it { is_expected.to fail_to_find_a_model(:boost) }
    end

    context "when user cannot destroy the boost" do
      fab!(:acting_user, :user)
      fab!(:boost) { Fabricate(:boost, post: post, user: post_author) }

      it { is_expected.to fail_a_policy(:can_destroy_boost) }
    end

    context "when post is in a restricted category" do
      fab!(:group)
      fab!(:private_category) { Fabricate(:private_category, group: group) }
      fab!(:private_topic) { Fabricate(:topic, category: private_category) }
      fab!(:private_post) { Fabricate(:post, topic: private_topic, user: post_author) }
      fab!(:boost) { Fabricate(:boost, post: private_post, user: acting_user) }

      it { is_expected.to fail_a_policy(:can_destroy_boost) }
    end

    context "when acting user is a moderator" do
      fab!(:acting_user, :moderator)
      fab!(:boost) { Fabricate(:boost, post: post, user: post_author) }

      it { is_expected.to run_successfully }
    end

    context "when acting user is an admin" do
      fab!(:acting_user, :admin)
      fab!(:boost) { Fabricate(:boost, post: post, user: post_author) }

      it { is_expected.to run_successfully }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "destroys the boost" do
        expect { result }.to change { DiscourseBoosts::Boost.count }.by(-1)
        expect(DiscourseBoosts::Boost.exists?(boost.id)).to eq(false)
      end

      it "publishes a boost_removed message to the topic channel" do
        messages = MessageBus.track_publish("/topic/#{topic.id}") { result }
        boost_message = messages.find { |m| m.data[:type] == :boost_removed }
        expect(boost_message).to be_present
        expect(boost_message.data[:id]).to eq(post.id)
        expect(boost_message.data[:boost_id]).to eq(boost.id)
      end
    end
  end
end

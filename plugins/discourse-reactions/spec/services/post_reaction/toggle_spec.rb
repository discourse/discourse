# frozen_string_literal: true

RSpec.describe DiscourseReactions::PostReaction::Toggle do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:post_id) }
    it { is_expected.to validate_presence_of(:reaction) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:acting_user, :user)
    fab!(:topic, :topic_with_op)
    let(:post) { topic.first_post }
    let(:params) { { post_id:, reaction: } }
    let(:dependencies) { { guardian: } }
    let(:guardian) { acting_user.guardian }
    let(:post_id) { post.id }
    let(:reaction) { "laughing" }
    let(:channel) { "/topic/#{post.topic_id}/reactions" }
    let(:messages) { MessageBus.track_publish(channel) { result } }

    before do
      SiteSetting.discourse_reactions_enabled = true
      SiteSetting.discourse_reactions_enabled_reactions = "laughing|hugs"
    end

    context "when the contract is invalid" do
      let(:reaction) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when the post does not exist" do
      let(:post_id) { 0 }

      it { is_expected.to fail_to_find_a_model(:post) }
    end

    context "when the user cannot see the post" do
      fab!(:private_topic, :private_message_topic)
      let(:post) { Fabricate(:post, topic: private_topic) }

      it { is_expected.to fail_a_policy(:can_see_post) }
    end

    context "when the reaction is invalid" do
      let(:reaction) { "invalid-reaction" }

      it { is_expected.to fail_a_policy(:reaction_is_valid) }
    end

    context "when the reaction cannot be toggled" do
      before { acting_user.update!(silenced_till: 1.day.from_now) }

      it { is_expected.to fail_with_exception(Discourse::InvalidAccess) }
    end

    context "when the topic is unavailable" do
      before do
        Post.stubs(:find_by).with(id: post.id).returns(post)
        guardian.stubs(:can_see?).with(post).returns(true)
        guardian.stubs(:can_use_reactions?).with(post).returns(true)
        acting_user.stubs(:guardian).returns(guardian)
        post.stubs(:topic).returns(nil)
      end

      it "toggles the reaction without publishing a reaction change" do
        expect(messages).to be_empty
        expect(result).to run_successfully
        expect(DiscourseReactions::ReactionUser.exists?(user: acting_user, post:)).to eq(true)
      end
    end

    context "when the secure audience is empty" do
      fab!(:restricted_category) { Fabricate(:category, read_restricted: true) }
      fab!(:restricted_topic) { Fabricate(:topic, category: restricted_category) }
      fab!(:acting_user, :admin)
      let(:post) { Fabricate(:post, topic: restricted_topic) }

      it "toggles the reaction without publishing a reaction change" do
        expect(messages).to be_empty
        expect(result).to run_successfully
        expect(DiscourseReactions::ReactionUser.exists?(user: acting_user, post:)).to eq(true)
      end
    end

    context "when the topic has a secure audience" do
      fab!(:recipient, :user)
      fab!(:acting_user, :admin)
      fab!(:private_topic) do
        Fabricate(:private_message_topic, user: recipient, recipient: acting_user)
      end
      let(:post) { Fabricate(:post, topic: private_topic) }

      it "publishes the reaction change only to the private-message participants" do
        expect(messages.size).to eq(1)
        expect(messages.first.user_ids).to contain_exactly(recipient.id, acting_user.id)
        expect(messages.first.group_ids).to be_nil
      end
    end

    context "when the reaction can be toggled" do
      it { is_expected.to run_successfully }

      it "creates the reaction" do
        expect { result }.to change { DiscourseReactions::ReactionUser.count }.by(1)
        expect(DiscourseReactions::ReactionUser.exists?(user: acting_user, post:)).to eq(true)
      end

      it "publishes the changed reaction" do
        expect(messages.size).to eq(1)
        expect(messages.first.data).to include(post_id: post.id, reactions: [reaction])
      end
    end
  end
end

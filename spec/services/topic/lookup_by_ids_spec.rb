# frozen_string_literal: true

RSpec.describe Topic::LookupByIds do
  describe described_class::Contract, type: :model do
    let(:max_ids) { Topic::LookupByIds::MAX_TOPIC_IDS }

    it { is_expected.to validate_presence_of(:topic_ids) }
    it { is_expected.to allow_values([1, 2], Array.new(max_ids) { it + 1 }).for(:topic_ids) }

    it do
      is_expected.not_to allow_values([1, "latest"], Array.new(max_ids + 1) { it + 1 }).for(
        :topic_ids,
      )
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:acting_user, :user)
    fab!(:group)
    fab!(:private_category) { Fabricate(:private_category, group:) }
    fab!(:public_topic, :topic)
    fab!(:other_public_topic, :topic)
    fab!(:secured_topic) { Fabricate(:topic, category: private_category) }
    fab!(:message_with_user) { Fabricate(:private_message_topic, recipient: acting_user) }
    fab!(:message_without_user, :private_message_topic)

    let(:params) { { topic_ids: } }
    let(:dependencies) { { guardian: acting_user.guardian } }
    let(:topic_ids) { [public_topic.id, other_public_topic.id] }

    context "when contract is invalid" do
      let(:topic_ids) { [public_topic.id, "latest"] }

      it { is_expected.to fail_a_contract }
    end

    context "without any visible topic matching" do
      let(:topic_ids) { [secured_topic.id, message_without_user.id] }

      it { is_expected.to run_successfully }

      it "answers no topics" do
        expect(result.topics).to be_empty
      end
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "answers the requested topics" do
        expect(result.topics).to contain_exactly(public_topic, other_public_topic)
      end
    end

    context "with a topic in a category the user cannot see" do
      let(:topic_ids) { [public_topic.id, secured_topic.id] }

      it "leaves it out" do
        expect(result.topics).to contain_exactly(public_topic)
      end
    end

    context "with a message the user is not in" do
      let(:topic_ids) { [public_topic.id, message_without_user.id] }

      it "leaves it out" do
        expect(result.topics).to contain_exactly(public_topic)
      end
    end

    context "with a message the user takes part in" do
      let(:topic_ids) { [message_with_user.id] }

      it "answers it" do
        expect(result.topics).to contain_exactly(message_with_user)
      end
    end

    context "with topics the user muted" do
      fab!(:muted_category, :category)
      fab!(:topic_in_muted_category) { Fabricate(:topic, category: muted_category) }

      let(:topic_ids) { [public_topic.id, topic_in_muted_category.id] }

      before do
        CategoryUser.set_notification_level_for_category(
          acting_user,
          CategoryUser.notification_levels[:muted],
          muted_category.id,
        )
        TopicUser.change(
          acting_user.id,
          public_topic.id,
          notification_level: TopicUser.notification_levels[:muted],
        )
      end

      it "still answers them" do
        expect(result.topics).to contain_exactly(public_topic, topic_in_muted_category)
      end
    end

    context "with an anonymous user" do
      let(:dependencies) { { guardian: Guardian.new } }
      let(:topic_ids) { [public_topic.id, secured_topic.id, message_with_user.id] }

      it "answers only the public topics" do
        expect(result.topics).to contain_exactly(public_topic)
      end
    end

    context "with an admin" do
      fab!(:acting_user, :admin)

      let(:topic_ids) { [public_topic.id, secured_topic.id] }

      it "answers topics in secured categories" do
        expect(result.topics).to contain_exactly(public_topic, secured_topic)
      end
    end

    context "with a shared draft the user cannot see" do
      fab!(:shared_drafts_category, :category)
      fab!(:shared_draft_topic) { Fabricate(:topic, category: shared_drafts_category) }
      fab!(:shared_draft) { Fabricate(:shared_draft, topic: shared_draft_topic) }

      let(:topic_ids) { [public_topic.id, shared_draft_topic.id] }

      before do
        SiteSetting.shared_drafts_category = shared_drafts_category.id
        SiteSetting.shared_drafts_allowed_groups = Group::AUTO_GROUPS[:staff]
      end

      it "leaves it out" do
        expect(result.topics).to contain_exactly(public_topic)
      end
    end
  end
end

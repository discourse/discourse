# frozen_string_literal: true

RSpec.describe DiscourseSolved::MeToo::Toggle do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:topic_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:author, :user)
    fab!(:acting_user, :user)
    fab!(:category)
    fab!(:topic) { Fabricate(:topic_with_op, category:, user: author) }

    let(:params) { { topic_id: topic.id } }
    let(:dependencies) { { guardian: acting_user.guardian } }

    before do
      SiteSetting.solved_enabled = true
      SiteSetting.allow_solved_on_all_topics = true
      SiteSetting.enable_solved_me_too = true
    end

    context "when contract is invalid" do
      let(:params) { {} }

      it { is_expected.to fail_a_contract }
    end

    context "when topic is not found" do
      let(:params) { { topic_id: -1 } }

      it { is_expected.to fail_to_find_a_model(:topic) }
    end

    context "when user cannot me-too the topic" do
      context "when the feature flag is disabled" do
        before { SiteSetting.enable_solved_me_too = false }

        it { is_expected.to fail_a_policy(:can_me_too) }
      end

      context "when the topic is already solved" do
        fab!(:answer_post) { Fabricate(:post, topic:) }

        before { Fabricate(:solved_topic, topic:, answer_post:, accepter: author) }

        it { is_expected.to fail_a_policy(:can_me_too) }
      end

      context "when the acting user is the topic author" do
        fab!(:acting_user) { author }

        it { is_expected.to fail_a_policy(:can_me_too) }
      end

      context "when the topic is a private message" do
        fab!(:topic) { Fabricate(:private_message_topic, user: author) }

        it { is_expected.to fail_a_policy(:can_me_too) }
      end

      context "when the guardian is anonymous" do
        let(:dependencies) { { guardian: Guardian.new } }

        it { is_expected.to fail_a_policy(:can_me_too) }
      end
    end

    context "when no me-too has been recorded yet" do
      let(:messages) { MessageBus.track_publish("/topic/#{topic.id}") { result } }

      it { is_expected.to run_successfully }

      it "creates a me-too record" do
        expect { result }.to change {
          DiscourseSolved::MeToo.where(topic:, user: acting_user).count
        }.by(1)
      end

      it "raises the notification level to tracking" do
        expect { result }.to change { TopicUser.get(topic, acting_user)&.notification_level }.to(
          TopicUser.notification_levels[:tracking],
        )
      end

      context "when the user is already watching the topic" do
        before do
          TopicUser.change(
            acting_user.id,
            topic.id,
            notification_level: TopicUser.notification_levels[:watching],
          )
        end

        it "does not lower the notification level" do
          expect { result }.not_to change { TopicUser.get(topic, acting_user).notification_level }
        end
      end

      context "when the user is already tracking the topic" do
        before do
          TopicUser.change(
            acting_user.id,
            topic.id,
            notification_level: TopicUser.notification_levels[:tracking],
          )
        end

        it "does not change the notification level" do
          expect { result }.not_to change { TopicUser.get(topic, acting_user).notification_level }
        end
      end

      it "publishes a me-too message indicating the user did me-too" do
        expect(messages).to include(
          an_object_having_attributes(
            data: a_hash_including(type: :me_too, count: 2, user_did_me_too: true),
          ),
        )
      end
    end

    context "when the user has already recorded a me-too" do
      let(:messages) { MessageBus.track_publish("/topic/#{topic.id}") { result } }

      before { Fabricate(:me_too, topic:, user: acting_user) }

      it { is_expected.to run_successfully }

      it "removes the me-too record" do
        expect { result }.to change {
          DiscourseSolved::MeToo.where(topic:, user: acting_user).count
        }.by(-1)
      end

      context "when the user is already tracking the topic" do
        before do
          TopicUser.change(
            acting_user.id,
            topic.id,
            notification_level: TopicUser.notification_levels[:tracking],
          )
        end

        it "does not change the notification level" do
          expect { result }.not_to change { TopicUser.get(topic, acting_user).notification_level }
        end
      end

      it "publishes a me-too message indicating the user withdrew their me-too" do
        expect(messages).to include(
          an_object_having_attributes(
            data: a_hash_including(type: :me_too, count: 1, user_did_me_too: false),
          ),
        )
      end
    end
  end
end

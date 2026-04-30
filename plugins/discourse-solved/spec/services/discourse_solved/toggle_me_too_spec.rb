# frozen_string_literal: true

RSpec.describe DiscourseSolved::ToggleMeToo do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:topic_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:author, :user)
    fab!(:acting_user, :user)
    fab!(:category)
    fab!(:topic) { Fabricate(:topic, category:, user: author) }
    fab!(:post_1, :post) { Fabricate(:post, topic:) }

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

    context "when feature flag is off" do
      before { SiteSetting.enable_solved_me_too = false }

      it { is_expected.to fail_a_policy(:can_me_too) }
    end

    context "when topic is already solved" do
      fab!(:answer_post) { Fabricate(:post, topic:) }
      before { Fabricate(:solved_topic, topic:, answer_post:, accepter: author) }

      it { is_expected.to fail_a_policy(:can_me_too) }
    end

    context "when acting user is the topic author" do
      let(:dependencies) { { guardian: author.guardian } }

      it { is_expected.to fail_a_policy(:can_me_too) }
    end

    context "when topic is a private message" do
      fab!(:topic) { Fabricate(:private_message_topic, user: author) }

      it { is_expected.to fail_a_policy(:can_me_too) }
    end

    context "when guardian is anonymous" do
      let(:dependencies) { { guardian: Guardian.new } }

      it { is_expected.to fail_a_policy(:can_me_too) }
    end

    context "when no me-too has been recorded yet" do
      it { is_expected.to run_successfully }

      it "creates a me-too record" do
        expect { result }.to change {
          DiscourseSolved::MeToo.where(topic:, user: acting_user).count
        }.by(1)
      end

      it "raises notification level to tracking" do
        expect { result }.to change { TopicUser.get(topic, acting_user)&.notification_level }.to(
          TopicUser.notification_levels[:tracking],
        )
      end

      context "when user is already watching the topic" do
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

      context "when user is already tracking" do
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

      it "publishes a me-too message" do
        messages = MessageBus.track_publish("/topic/#{topic.id}") { result }
        me_too_message = messages.find { |m| m.data[:type] == :me_too }
        expect(me_too_message).to be_present
        expect(me_too_message.data[:count]).to eq(2)
        expect(me_too_message.data[:user_did_me_too]).to eq(true)
      end
    end

    context "when the user has already recorded a me-too" do
      before { DiscourseSolved::MeToo.create!(topic:, user: acting_user) }

      it { is_expected.to run_successfully }

      it "removes the me-too record" do
        expect { result }.to change {
          DiscourseSolved::MeToo.where(topic:, user: acting_user).count
        }.by(-1)
      end

      it "does not change the notification level" do
        TopicUser.change(
          acting_user.id,
          topic.id,
          notification_level: TopicUser.notification_levels[:tracking],
        )
        expect { result }.not_to change { TopicUser.get(topic, acting_user).notification_level }
      end

      it "publishes a me-too message indicating withdrawal" do
        messages = MessageBus.track_publish("/topic/#{topic.id}") { result }
        me_too_message = messages.find { |m| m.data[:type] == :me_too }
        expect(me_too_message).to be_present
        expect(me_too_message.data[:count]).to eq(1)
        expect(me_too_message.data[:user_did_me_too]).to eq(false)
      end
    end
  end
end

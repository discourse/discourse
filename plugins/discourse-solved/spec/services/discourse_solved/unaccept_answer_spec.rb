# frozen_string_literal: true

RSpec.describe DiscourseSolved::UnacceptAnswer do
  describe ".call" do
    subject(:result) { described_class.call(params:) }

    fab!(:user)
    fab!(:topic) { Fabricate(:topic, user:) }
    fab!(:post_1, :post) { Fabricate(:post, topic:) }
    fab!(:post) { Fabricate(:post, topic:) }

    let(:params) { { post_id: post.id } }

    before do
      SiteSetting.solved_enabled = true
      SiteSetting.allow_solved_on_all_topics = true
    end

    context "when contract is invalid" do
      let(:params) { {} }

      it { is_expected.to fail_a_contract }
    end

    context "when post is not found" do
      let(:params) { { post_id: -1 } }

      it { is_expected.to fail_to_find_a_model(:post) }
    end

    context "when topic is not found" do
      before do
        topic.destroy!
        post.update_columns(topic_id: -1)
      end

      it { is_expected.to fail_to_find_a_model(:topic) }
    end

    context "when the post is not the accepted answer" do
      it { is_expected.to run_successfully }

      it "does not change anything" do
        expect { result }.not_to change { DiscourseSolved::SolvedTopic.count }
      end
    end

    context "when the post is the accepted answer" do
      fab!(:solved_topic) { Fabricate(:solved_topic, topic:, answer_post: post, accepter: user) }

      before do
        UserAction.log_action!(
          action_type: UserAction::SOLVED,
          user_id: post.user_id,
          acting_user_id: user.id,
          target_post_id: post.id,
          target_topic_id: topic.id,
        )
      end

      it { is_expected.to run_successfully }

      it "destroys the solved topic record" do
        expect { result }.to change { DiscourseSolved::SolvedTopic.count }.by(-1)
      end

      it "removes the user action" do
        expect { result }.to change {
          UserAction.where(action_type: UserAction::SOLVED, target_post_id: post.id).count
        }.by(-1)
      end

      it "triggers the :unaccepted_solution event" do
        events = DiscourseEvent.track_events(:unaccepted_solution) { result }
        expect(events.length).to eq(1)
        expect(events.first[:params]).to eq([post])
      end

      it "publishes to MessageBus" do
        messages = MessageBus.track_publish("/topic/#{topic.id}") { result }
        expect(messages.any? { |m| m.data[:type] == :unaccepted_solution }).to eq(true)
      end

      it "removes the notification" do
        Notification.create!(
          notification_type: Notification.types[:custom],
          user_id: post.user_id,
          topic_id: post.topic_id,
          post_number: post.post_number,
          data: { message: "solved.accepted_notification" }.to_json,
        )

        expect { result }.to change {
          Notification.where(
            notification_type: Notification.types[:custom],
            user_id: post.user_id,
            topic_id: post.topic_id,
            post_number: post.post_number,
          ).count
        }.by(-1)
      end

      context "when a different post is the accepted answer" do
        before { solved_topic.update!(answer_post: post_1) }

        it "does not destroy the solved record" do
          expect { result }.not_to change { DiscourseSolved::SolvedTopic.count }
        end
      end
    end
  end
end

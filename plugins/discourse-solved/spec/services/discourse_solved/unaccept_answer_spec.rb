# frozen_string_literal: true

RSpec.describe DiscourseSolved::UnacceptAnswer do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:post_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:user)
    fab!(:topic) { Fabricate(:topic, user:) }
    fab!(:post_1, :post) { Fabricate(:post, topic:) }
    fab!(:post) { Fabricate(:post, topic:) }

    let(:params) { { post_id: post.id } }
    let(:guardian) { user.guardian }
    let(:dependencies) { { guardian: } }

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

    context "when post is trashed" do
      before { post.trash! }

      it { is_expected.to fail_to_find_a_model(:post) }

      context "when user is staff" do
        fab!(:user, :admin)

        it { is_expected.to run_successfully }
      end
    end

    context "when topic is not found" do
      before { post.topic.destroy! }

      it { is_expected.to fail_to_find_a_model(:topic) }
    end

    context "when topic is trashed" do
      before { post.topic.trash! }

      it { is_expected.to fail_to_find_a_model(:topic) }

      context "when user is staff" do
        fab!(:user, :admin)

        it { is_expected.to run_successfully }
      end
    end

    context "when user cannot unaccept answer" do
      let(:guardian) { Guardian.new }

      it { is_expected.to fail_a_policy(:can_unaccept_answer) }
    end

    context "when the post is not the accepted answer" do
      it { is_expected.to run_successfully }

      it "does not mark the topic as unsolved" do
        expect { result }.not_to change { DiscourseSolved::SolvedTopic.count }
      end
    end

    context "when the post is the accepted answer" do
      fab!(:solved_topic) { Fabricate(:solved_topic, topic:, answer_post: post, accepter: user) }

      let(:messages) { MessageBus.track_publish("/topic/#{topic.id}") { result } }
      let(:events) { DiscourseEvent.track_events(:unaccepted_solution) { result } }

      before do
        UserAction.log_action!(
          action_type: UserAction::SOLVED,
          user_id: post.user_id,
          acting_user_id: user.id,
          target_post_id: post.id,
          target_topic_id: topic.id,
        )
        Notification.create!(
          notification_type: Notification.types[:custom],
          user_id: post.user_id,
          topic_id: post.topic_id,
          post_number: post.post_number,
          data: { message: "solved.accepted_notification" }.to_json,
        )
      end

      it { is_expected.to run_successfully }

      it "revokes the post author's solved credit" do
        expect { result }.to change {
          UserAction.where(action_type: UserAction::SOLVED, target_post: post).count
        }.by(-1)
      end

      it "removes the accepted answer notification" do
        expect { result }.to change {
          Notification.where(
            notification_type: Notification.types[:custom],
            user: post.user,
            topic: post.topic,
            post_number: post.post_number,
          ).count
        }.by(-1)
      end

      it "marks the topic as unsolved" do
        expect { result }.to change { DiscourseSolved::SolvedTopic.count }.by(-1)
      end

      context "when an unaccepted_solution webhook is active" do
        fab!(:web_hook) { Fabricate(:web_hook, active: true) }
        fab!(:unaccepted_solution_event_type) do
          WebHookEventType.find_by(name: "unaccepted_solution")
        end

        before { web_hook.web_hook_event_types << unaccepted_solution_event_type }

        it "enqueues the webhook" do
          expect { result }.to change { Jobs::EmitWebHookEvent.jobs.size }.by(1)
        end
      end

      it "triggers the :unaccepted_solution event" do
        expect(events).to include(a_hash_including(params: [post]))
      end

      it "broadcasts the unaccepted solution" do
        expect(messages).to include(
          an_object_having_attributes(data: a_hash_including(type: :unaccepted_solution)),
        )
      end

      context "when the post is trashed" do
        fab!(:user, :admin)

        before { post.trash! }

        it "still marks the topic as unsolved" do
          expect { result }.to change { DiscourseSolved::SolvedTopic.count }.by(-1)
        end
      end

      context "when a different post is the accepted answer" do
        before { solved_topic.update!(answer_post: post_1) }

        it "does not mark the topic as unsolved" do
          expect { result }.not_to change { DiscourseSolved::SolvedTopic.count }
        end
      end
    end
  end
end

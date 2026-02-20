# frozen_string_literal: true

RSpec.describe DiscourseSolved::AcceptAnswer do
  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:acting_user, :user)
    fab!(:category)
    fab!(:topic) { Fabricate(:topic, category:, user: acting_user) }
    fab!(:post_1, :post) { Fabricate(:post, topic:) }
    fab!(:post) { Fabricate(:post, topic:) }

    let(:params) { { post_id: post.id } }
    let(:dependencies) { { guardian: Guardian.new(acting_user) } }

    before do
      SiteSetting.solved_enabled = true
      SiteSetting.allow_solved_on_all_topics = true
    end

    context "when post_id is blank" do
      let(:params) { { post_id: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when post is not found" do
      let(:params) { { post_id: -1 } }

      it { is_expected.to fail_to_find_a_model(:post) }
    end

    context "when topic is not found" do
      before { post.topic.destroy! }

      it { is_expected.to fail_to_find_a_model(:topic) }
    end

    context "when everything is valid" do
      it { is_expected.to run_successfully }

      it "creates a solved topic record" do
        expect { result }.to change { DiscourseSolved::SolvedTopic.count }.by(1)
        solved = DiscourseSolved::SolvedTopic.last
        expect(solved).to have_attributes(
          topic_id: topic.id,
          answer_post_id: post.id,
          accepter_user_id: acting_user.id,
        )
      end

      it "logs a user action" do
        expect { result }.to change {
          UserAction.where(action_type: UserAction::SOLVED, target_post_id: post.id).count
        }.by(1)
      end

      it "triggers the :accepted_solution event" do
        events = DiscourseEvent.track_events(:accepted_solution) { result }
        expect(events.length).to eq(1)
        expect(events.first[:params]).to eq([post])
      end

      it "publishes to MessageBus" do
        messages = MessageBus.track_publish("/topic/#{topic.id}") { result }
        expect(messages.any? { |m| m.data[:type] == :accepted_solution }).to eq(true)
      end

      context "when the acting user is not the post author" do
        fab!(:acting_user, :admin)

        it "creates a notification for the post author" do
          expect { result }.to change {
            Notification.where(
              notification_type: Notification.types[:custom],
              user_id: post.user_id,
            ).count
          }.by(1)
        end
      end

      context "when the acting user is the post author" do
        let(:dependencies) { { guardian: Guardian.new(post.user) } }

        it "does not notify the post author" do
          expect { result }.not_to change {
            Notification.where(
              notification_type: Notification.types[:custom],
              user_id: post.user_id,
            ).count
          }
        end
      end

      context "when notify_on_staff_accept_solved is enabled" do
        before { SiteSetting.notify_on_staff_accept_solved = true }

        context "when a staff member accepts on behalf of the topic owner" do
          fab!(:acting_user, :admin)

          it "notifies the topic owner" do
            expect { result }.to change {
              Notification.where(
                notification_type: Notification.types[:custom],
                user_id: topic.user_id,
              ).count
            }.by(1)
          end
        end
      end

      context "when a previous answer was already accepted" do
        let!(:existing_solved) do
          Fabricate(:solved_topic, topic:, answer_post: post_1, accepter: acting_user)
        end

        it "replaces the previous solved record" do
          expect { result }.not_to change { DiscourseSolved::SolvedTopic.count }
          expect(topic.reload.solved.answer_post_id).to eq(post.id)
        end

        it "removes the old user action" do
          UserAction.log_action!(
            action_type: UserAction::SOLVED,
            user_id: post_1.user_id,
            acting_user_id: acting_user.id,
            target_post_id: post_1.id,
            target_topic_id: topic.id,
          )

          expect { result }.to change {
            UserAction.where(action_type: UserAction::SOLVED, target_post_id: post_1.id).count
          }.by(-1)
        end
      end

      context "when solved_topics_auto_close_hours is set" do
        before { SiteSetting.solved_topics_auto_close_hours = 48 }

        it "creates a topic timer" do
          expect { result }.to change { TopicTimer.count }.by(1)
          expect(TopicTimer.last.topic).to eq(topic)
        end

        it "stores the timer on the solved record" do
          result
          solved = DiscourseSolved::SolvedTopic.last
          expect(solved.topic_timer_id).to be_present
        end
      end

      context "when the topic is already closed" do
        before { topic.update!(closed: true) }

        it "does not create a topic timer" do
          SiteSetting.solved_topics_auto_close_hours = 48
          expect { result }.not_to change { TopicTimer.count }
        end
      end
    end
  end
end

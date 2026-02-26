# frozen_string_literal: true

RSpec.describe DiscourseSolved::Answer::Accept do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:post_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:acting_user, :trust_level_4)
    fab!(:topic, :topic_with_op)
    fab!(:reply) { Fabricate(:post, topic:) }

    let(:params) { { post_id: reply.id } }
    let(:dependencies) { { guardian: acting_user.guardian } }

    before { SiteSetting.allow_solved_on_all_topics = true }

    context "when contract is invalid" do
      let(:params) { { post_id: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when post is not found" do
      let(:params) { { post_id: 0 } }

      it { is_expected.to fail_to_find_a_model(:post) }
    end

    context "when topic is not found" do
      before { topic.trash!(Discourse.system_user) }

      it { is_expected.to fail_to_find_a_model(:topic) }
    end

    context "when topic is trashed and user is staff" do
      fab!(:acting_user, :admin)

      before { topic.trash!(Discourse.system_user) }

      it { is_expected.to run_successfully }
    end

    context "when user cannot accept answer" do
      fab!(:acting_user, :user)

      it { is_expected.to fail_a_policy(:can_accept_answer) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "creates a solved topic" do
        expect { result }.to change { DiscourseSolved::SolvedTopic.count }.by(1)
        expect(topic.reload.solved).to have_attributes(
          answer_post_id: reply.id,
          accepter_user_id: acting_user.id,
        )
      end

      it "creates a user action" do
        expect { result }.to change {
          UserAction.where(action_type: UserAction::SOLVED, target_post_id: reply.id).count
        }.by(1)
      end

      it "triggers the accepted_solution event" do
        events = DiscourseEvent.track_events(:accepted_solution) { result }
        expect(events.size).to eq(1)
        expect(events.first[:params]).to eq([reply])
      end

      it "publishes a solution update message" do
        messages = MessageBus.track_publish("/topic/#{topic.id}") { result }
        accepted_message = messages.find { |m| m.data[:type] == :accepted_solution }
        expect(accepted_message).to be_present
        expect(accepted_message.data[:accepted_answer][:post_number]).to eq(reply.post_number)
      end

      context "when a previous solution exists" do
        fab!(:previous_reply) { Fabricate(:post, topic:) }
        fab!(:previous_solution) { Fabricate(:solved_topic, topic:, answer_post: previous_reply) }

        it { is_expected.to run_successfully }

        it "destroys the previous solution" do
          expect { result }.not_to change { DiscourseSolved::SolvedTopic.count }
          expect(topic.reload.solved.answer_post_id).to eq(reply.id)
        end

        it "removes the previous user action and creates a new one" do
          UserAction.log_action!(
            action_type: UserAction::SOLVED,
            user_id: previous_reply.user_id,
            acting_user_id: acting_user.id,
            target_post_id: previous_reply.id,
            target_topic_id: topic.id,
          )

          result

          expect(
            UserAction.where(action_type: UserAction::SOLVED, target_post_id: previous_reply.id),
          ).to be_empty
          expect(
            UserAction.where(action_type: UserAction::SOLVED, target_post_id: reply.id),
          ).to be_present
        end
      end

      context "with notifications" do
        fab!(:answer_author, :user)
        fab!(:topic, :topic_with_op)
        fab!(:reply) { Fabricate(:post, topic:, user: answer_author) }

        it "notifies the answer author" do
          expect { result }.to change { answer_author.notifications.count }.by(1)
          notification = answer_author.notifications.last
          expect(notification.notification_type).to eq(Notification.types[:custom])
          expect(notification.topic_id).to eq(topic.id)
          expect(notification.post_number).to eq(reply.post_number)
        end

        context "when the accepter is the answer author" do
          fab!(:acting_user) { answer_author }

          before { acting_user.update!(trust_level: TrustLevel[4]) }

          it "does not notify the answer author" do
            expect { result }.not_to change { answer_author.notifications.count }
          end
        end

        context "when the answer author is muting the accepter" do
          before { MutedUser.create!(user_id: answer_author.id, muted_user_id: acting_user.id) }

          it "does not notify the answer author" do
            expect { result }.not_to change { answer_author.notifications.count }
          end
        end

        context "when notify_on_staff_accept_solved is enabled" do
          fab!(:topic_author, :user)
          fab!(:topic) { Fabricate(:topic_with_op, user: topic_author) }
          fab!(:reply) { Fabricate(:post, topic:, user: answer_author) }

          before { SiteSetting.notify_on_staff_accept_solved = true }

          it "notifies the topic author" do
            expect { result }.to change { topic_author.notifications.count }.by(1)
          end

          context "when the accepter is the topic author" do
            fab!(:acting_user) { topic_author }

            before { acting_user.update!(trust_level: TrustLevel[4]) }

            it "does not notify the topic author" do
              expect { result }.not_to change { topic_author.notifications.count }
            end
          end

          context "when the topic author is muting the accepter" do
            before { MutedUser.create!(user_id: topic_author.id, muted_user_id: acting_user.id) }

            it "does not notify the topic author" do
              expect { result }.not_to change { topic_author.notifications.count }
            end
          end
        end

        context "when notify_on_staff_accept_solved is disabled" do
          fab!(:topic_author, :user)
          fab!(:topic) { Fabricate(:topic_with_op, user: topic_author) }
          fab!(:reply) { Fabricate(:post, topic:, user: answer_author) }

          before { SiteSetting.notify_on_staff_accept_solved = false }

          it "does not notify the topic author" do
            expect { result }.not_to change { topic_author.notifications.count }
          end
        end
      end

      context "with auto-close" do
        before { SiteSetting.solved_topics_auto_close_hours = 2 }

        it "schedules auto-close timer" do
          freeze_time

          result
          topic.reload

          last_post = topic.posts.order(:created_at).last
          expect(topic.public_topic_timer.status_type).to eq(TopicTimer.types[:silent_close])
          expect(topic.public_topic_timer.execute_at).to eq_time(last_post.created_at + 2.hours)
          expect(topic.public_topic_timer.based_on_last_post).to eq(true)
          expect(topic.solved.topic_timer).to eq(topic.public_topic_timer)
        end

        it "publishes a reload_topic message" do
          messages = MessageBus.track_publish("/topic/#{topic.id}") { result }
          reload_message = messages.find { |m| m.data[:reload_topic] }
          expect(reload_message).to be_present
        end

        context "when topic is closed" do
          before { topic.update!(closed: true) }

          it "does not schedule auto-close" do
            result
            topic.reload
            expect(topic.public_topic_timer).to be_nil
          end
        end

        context "with category-specific auto-close hours" do
          before do
            topic.category.custom_fields["solved_topics_auto_close_hours"] = 4
            topic.category.save_custom_fields
          end

          it "uses the category setting" do
            freeze_time

            result
            topic.reload

            last_post = topic.posts.order(:created_at).last
            expect(topic.public_topic_timer.execute_at).to eq_time(last_post.created_at + 4.hours)
          end
        end
      end

      context "with webhooks" do
        before { Fabricate(:solved_web_hook) }

        it "enqueues the webhook event" do
          result
          job_args = Jobs::EmitWebHookEvent.jobs[0]["args"].first
          expect(job_args["event_name"]).to eq("accepted_solution")
        end
      end

      context "with secure messaging" do
        fab!(:private_user, :user)
        fab!(:acting_user, :admin)
        fab!(:topic) do
          Fabricate(:private_message_topic, user: private_user, recipient: acting_user)
        end
        fab!(:op) { Fabricate(:post, topic:) }
        fab!(:reply) { Fabricate(:post, topic:) }

        it "publishes with secure audience" do
          messages = MessageBus.track_publish("/topic/#{topic.id}") { result }
          accepted_message = messages.find { |m| m.data[:type] == :accepted_solution }
          expect(accepted_message.user_ids).to include(private_user.id)
        end
      end
    end
  end
end

# frozen_string_literal: true

RSpec.describe DiscourseSolved::AcceptAnswer do
  describe ::DiscourseSolved::AcceptAnswer::Contract, type: :model do
    it { is_expected.to validate_presence_of(:post_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:acting_user, :user)
    fab!(:category)
    fab!(:topic) { Fabricate(:topic, category:, user: acting_user) }
    fab!(:post_1, :post) { Fabricate(:post, topic:) }
    fab!(:post) { Fabricate(:post, topic:) }

    let(:params) { { post_id: post.id } }
    let(:dependencies) { { guardian: } }
    let(:guardian) { acting_user.guardian }

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
      before { post.topic.destroy! }

      it { is_expected.to fail_to_find_a_model(:topic) }
    end

    context "when topic is trashed" do
      before { post.topic.trash! }

      it { is_expected.to fail_to_find_a_model(:topic) }

      context "when user is staff" do
        fab!(:acting_user, :admin)

        it { is_expected.to run_successfully }
      end
    end

    context "when user cannot accept answer" do
      let(:guardian) { Guardian.new }

      it { is_expected.to fail_a_policy(:can_accept_answer) }
    end

    context "when everything is valid" do
      let(:messages) { MessageBus.track_publish("/topic/#{topic.id}") { result } }
      let(:events) { DiscourseEvent.track_events(:accepted_solution) { result } }

      it { is_expected.to run_successfully }

      context "when a previous answer was already accepted" do
        fab!(:existing_solved) do
          Fabricate(:solved_topic, topic:, answer_post: post_1, accepter: acting_user)
        end
        fab!(:previous_user_action) do
          UserAction.log_action!(
            action_type: UserAction::SOLVED,
            user_id: post_1.user_id,
            acting_user_id: acting_user.id,
            target_post_id: post_1.id,
            target_topic_id: topic.id,
          )
        end

        it "keeps only one solution per topic" do
          expect { result }.not_to change { DiscourseSolved::SolvedTopic.count }
        end

        it "replaces the accepted answer" do
          expect { result }.to change { topic.reload.solved.answer_post }.from(post_1).to(post)
        end

        it "revokes the previous answer's solved credit" do
          expect { result }.to change {
            UserAction.where(action_type: UserAction::SOLVED, target_post: post_1).count
          }.by(-1)
        end
      end

      it "credits the post author with a solved action" do
        expect { result }.to change {
          UserAction.where(action_type: UserAction::SOLVED, target_post: post).count
        }.by(1)
      end

      it "marks the topic as solved" do
        expect(result[:solved]).to have_attributes(
          topic: topic,
          answer_post: post,
          accepter: acting_user,
        )
      end

      context "when the acting user is not the post author" do
        fab!(:acting_user, :admin)

        it "notifies the post author" do
          expect { result }.to change {
            Notification.where(
              notification_type: Notification.types[:custom],
              user: post.user,
            ).count
          }.by(1)
        end
      end

      context "when the acting user is the post author" do
        let(:guardian) { post.user.guardian }

        it "does not notify the post author" do
          expect { result }.not_to change {
            Notification.where(
              notification_type: Notification.types[:custom],
              user: post.user,
            ).count
          }
        end
      end

      context "when notify_on_staff_accept_solved is enabled" do
        before do
          category.notify_on_staff_accept_solved = true
          category.save_custom_fields
        end

        context "when a staff member accepts on behalf of the topic owner" do
          fab!(:acting_user, :admin)

          it "notifies the topic owner" do
            expect { result }.to change {
              Notification.where(
                notification_type: Notification.types[:custom],
                user: topic.user,
              ).count
            }.by(1)
          end
        end

        context "when the acting user is the topic owner" do
          it "does not notify the topic owner" do
            expect { result }.not_to change {
              Notification.where(
                notification_type: Notification.types[:custom],
                user: topic.user,
              ).count
            }
          end
        end
      end

      context "when notify_on_staff_accept_solved is disabled" do
        before do
          category.notify_on_staff_accept_solved = false
          category.save_custom_fields
        end

        it "does not notify the topic owner" do
          expect { result }.not_to change {
            Notification.where(
              notification_type: Notification.types[:custom],
              user: topic.user,
            ).count
          }
        end
      end

      context "when users are tracking or watching the topic" do
        fab!(:watching_user, :user)
        fab!(:tracking_user, :user)
        fab!(:muted_user, :user)
        fab!(:acting_user, :admin)

        before do
          TopicUser.change(
            watching_user.id,
            topic.id,
            notification_level: TopicUser.notification_levels[:watching],
          )
          TopicUser.change(
            tracking_user.id,
            topic.id,
            notification_level: TopicUser.notification_levels[:tracking],
          )
          TopicUser.change(
            muted_user.id,
            topic.id,
            notification_level: TopicUser.notification_levels[:muted],
          )
        end

        it "notifies watching users" do
          expect { result }.to change {
            Notification.where(
              notification_type: Notification.types[:custom],
              user: watching_user,
            ).count
          }.by(1)
        end

        it "notifies tracking users" do
          expect { result }.to change {
            Notification.where(
              notification_type: Notification.types[:custom],
              user: tracking_user,
            ).count
          }.by(1)
        end

        it "does not notify muted users" do
          expect { result }.not_to change {
            Notification.where(
              notification_type: Notification.types[:custom],
              user: muted_user,
            ).count
          }
        end

        it "does not notify the user who marked the solution" do
          TopicUser.change(
            acting_user.id,
            topic.id,
            notification_level: TopicUser.notification_levels[:watching],
          )

          expect { result }.not_to change {
            Notification.where(
              notification_type: Notification.types[:custom],
              user: acting_user,
            ).count
          }
        end

        it "uses the topic_solved_notification message" do
          result
          notification =
            Notification.find_by(
              notification_type: Notification.types[:custom],
              user: watching_user,
            )
          data = JSON.parse(notification.data)
          expect(data["message"]).to eq("solved.topic_solved_notification")
          expect(data["title"]).to eq("solved.notification.topic_solved_title")
        end

        it "does not double-notify the post author who is already notified" do
          TopicUser.change(
            post.user_id,
            topic.id,
            notification_level: TopicUser.notification_levels[:watching],
          )

          result
          notifications =
            Notification.where(
              notification_type: Notification.types[:custom],
              user: post.user,
              topic: topic,
            )
          expect(notifications.count).to eq(1)
          expect(JSON.parse(notifications.first.data)["message"]).to eq(
            "solved.accepted_notification",
          )
        end

        it "links to the solution post" do
          result
          notification =
            Notification.find_by(
              notification_type: Notification.types[:custom],
              user: watching_user,
            )
          expect(notification.post_number).to eq(post.post_number)
        end
      end

      context "when an accepted_solution webhook is active" do
        fab!(:web_hook) { Fabricate(:web_hook, active: true) }
        fab!(:accepted_solution_event_type) { WebHookEventType.find_by(name: "accepted_solution") }

        before { web_hook.web_hook_event_types << accepted_solution_event_type }

        it "enqueues the webhook" do
          expect { result }.to change { Jobs::EmitWebHookEvent.jobs.size }.by(1)
        end
      end

      context "when a topic timer is created" do
        before { SiteSetting.solved_topics_auto_close_hours = 48 }

        it "broadcasts a topic reload" do
          expect(messages.map(&:data)).to include(reload_topic: true)
        end
      end

      it "triggers the :accepted_solution event" do
        expect(events).to include(a_hash_including(params: [post]))
      end

      it "broadcasts the accepted solution" do
        expect(messages).to include(
          an_object_having_attributes(data: a_hash_including(type: :accepted_solution)),
        )
      end
    end
  end
end

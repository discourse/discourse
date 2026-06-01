# frozen_string_literal: true

RSpec.describe DiscourseSolved::SharedIssue::Toggle do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:topic_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:author, :user)
    fab!(:acting_user, :user)
    fab!(:category) do
      Fabricate(:category).tap do |c|
        c.upsert_custom_fields(DiscourseSolved::ENABLE_ACCEPTED_ANSWERS_CUSTOM_FIELD => "true")
      end
    end
    fab!(:topic) { Fabricate(:topic_with_op, category:, user: author) }

    let(:params) { { topic_id: topic.id } }
    let(:dependencies) { { guardian: acting_user.guardian } }

    before do
      SiteSetting.solved_enabled = true
      SiteSetting.enable_solved_shared_issues = true
      DiscourseSolved::AcceptedAnswerCache.reset_accepted_answer_cache
    end

    context "when contract is invalid" do
      let(:params) { {} }

      it { is_expected.to fail_a_contract }
    end

    context "when topic is not found" do
      let(:params) { { topic_id: -1 } }

      it { is_expected.to fail_to_find_a_model(:topic) }
    end

    context "when user cannot create a shared issue for the topic" do
      context "when the feature flag is disabled" do
        before { SiteSetting.enable_solved_shared_issues = false }

        it { is_expected.to fail_a_policy(:can_create_shared_issue) }
      end

      context "when the topic is already solved" do
        fab!(:answer_post) { Fabricate(:post, topic:) }

        before do
          solved_topic = Fabricate(:solved_topic, topic:)
          Fabricate(:topic_answer, solved_topic:, post: answer_post, accepter: author)
        end

        it { is_expected.to fail_a_policy(:can_create_shared_issue) }

        context "when allow_multiple_solutions is enabled" do
          before { SiteSetting.solved_allow_multiple_solutions = true }

          it { is_expected.to run_successfully }

          it "creates a shared issue record" do
            expect { result }.to change {
              DiscourseSolved::SharedIssue.where(topic:, user: acting_user).count
            }.by(1)
          end
        end
      end

      context "when the acting user is the topic author" do
        fab!(:acting_user) { author }

        it { is_expected.to fail_a_policy(:can_create_shared_issue) }
      end

      context "when the topic is a private message" do
        fab!(:topic) { Fabricate(:private_message_topic, user: author) }

        it { is_expected.to fail_a_policy(:can_create_shared_issue) }
      end

      context "when the topic is not in a support category" do
        fab!(:other_category, :category)
        fab!(:topic) { Fabricate(:topic_with_op, category: other_category, user: author) }

        it { is_expected.to fail_a_policy(:can_create_shared_issue) }
      end

      context "when allow_solved_on_all_topics is enabled but the category is not a support category" do
        fab!(:other_category, :category)
        fab!(:topic) { Fabricate(:topic_with_op, category: other_category, user: author) }

        before { SiteSetting.allow_solved_on_all_topics = true }

        it { is_expected.to fail_a_policy(:can_create_shared_issue) }
      end

      context "when the guardian is anonymous" do
        let(:dependencies) { { guardian: Guardian.new } }

        it { is_expected.to fail_a_policy(:can_create_shared_issue) }
      end
    end

    context "when no shared issue has been recorded yet" do
      let(:messages) { MessageBus.track_publish("/topic/#{topic.id}") { result } }

      it { is_expected.to run_successfully }

      it "creates a shared issue record" do
        expect { result }.to change {
          DiscourseSolved::SharedIssue.where(topic:, user: acting_user).count
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

      it "publishes a shared issue message indicating the user created a shared issue" do
        expect(messages).to include(
          an_object_having_attributes(
            data: a_hash_including(type: :shared_issue, count: 1, user_created_shared_issue: true),
          ),
        )
      end
    end

    context "when the user has already recorded a shared issue" do
      let(:messages) { MessageBus.track_publish("/topic/#{topic.id}") { result } }

      before { Fabricate(:shared_issue, topic:, user: acting_user) }

      it { is_expected.to run_successfully }

      it "removes the shared issue record" do
        expect { result }.to change {
          DiscourseSolved::SharedIssue.where(topic:, user: acting_user).count
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

      it "publishes a shared issue message indicating the user withdrew their shared issue" do
        expect(messages).to include(
          an_object_having_attributes(
            data: a_hash_including(type: :shared_issue, count: 0, user_created_shared_issue: false),
          ),
        )
      end
    end
  end
end

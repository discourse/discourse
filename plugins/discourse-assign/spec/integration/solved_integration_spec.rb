# frozen_string_literal: true

RSpec.describe "Solved integration", if: defined?(DiscourseSolved) do
  fab!(:user)
  fab!(:group)
  fab!(:topic) { Fabricate(:topic_with_op, user: user) }
  fab!(:post) { Fabricate(:post, topic: topic) }

  before do
    SiteSetting.solved_enabled = true
    SiteSetting.allow_solved_on_all_topics = true
    SiteSetting.assign_enabled = true
    SiteSetting.enable_assign_status = true
    SiteSetting.assign_allowed_on_groups = "#{group.id}"
    SiteSetting.assigns_public = true
    SiteSetting.assignment_status_on_solve = "Done"
    SiteSetting.assignment_status_on_unsolve = "New"
    SiteSetting.ignore_solved_topics_in_assigned_reminder = false
    group.add(post.acting_user)
    group.add(user)
  end

  describe "Reviewable#perform" do
    fab!(:admin)

    it "rolls back the penalty and assignment changes when a solution callback fails" do
      DiscourseSolved::AcceptAnswer.call!(params: { post_id: post.id }, guardian: admin.guardian)
      topic_assignment =
        Fabricate(
          :topic_assignment,
          target: topic,
          topic: topic,
          assigned_to: admin,
          status: "Done",
        )
      reviewable = Fabricate(:reviewable_flagged_post, target: post, target_created_by: post.user)
      author = post.user
      callback = ->(_post) { raise Discourse::InvalidParameters }
      DiscourseEvent.on(:unaccepted_solution, &callback)

      messages =
        MessageBus.track_publish do
          expect do
            reviewable.perform(
              admin,
              :agree_and_suspend,
              penalty: {
                reason: "spam",
                suspend_until: 2.days.from_now,
                post_action: "delete",
              },
            )
          end.to raise_error(Discourse::InvalidParameters)
        end

      expect(reviewable.reload).to be_pending
      expect(author.reload).not_to be_suspended
      expect(post.reload).not_to be_trashed
      expect(DiscourseSolved::TopicAnswer.exists?(answer_post_id: post.id)).to eq(true)
      expect(topic_assignment.reload.status).to eq("Done")
      expect(messages.map(&:channel)).not_to include(
        "/staff/topic-assignment",
        "/topic/#{topic.id}",
      )
    ensure
      DiscourseEvent.off(:unaccepted_solution, &callback) if callback
    end
  end

  describe "updating assignment status on solve" do
    it "updates all assignments to assignment_status_on_solve status when a post is accepted" do
      assigner = Assigner.new(topic, user)
      result = assigner.assign(user)
      expect(result[:success]).to eq(true)

      expect(topic.assignment.status).to eq("New")
      DiscourseSolved::AcceptAnswer.call!(params: { post_id: post.id }, guardian: user.guardian)
      topic.reload

      expect(topic.topic_answers[0].answer_post_id).to eq(post.id)
      expect(topic.assignment.reload.status).to eq("Done")
    end

    it "updates all assignments to assignment_status_on_unsolve status when a post is unaccepted" do
      assigner = Assigner.new(topic, user)
      result = assigner.assign(user)
      expect(result[:success]).to eq(true)

      DiscourseSolved::AcceptAnswer.call!(params: { post_id: post.id }, guardian: user.guardian)

      expect(topic.assignment.reload.status).to eq("Done")

      DiscourseSolved::UnacceptAnswer.call!(params: { post_id: post.id }, guardian: user.guardian)

      expect(topic.assignment.reload.status).to eq("New")
    end

    describe "with multiple solutions enabled" do
      fab!(:post2) { Fabricate(:post, topic: topic) }

      before { SiteSetting.solved_allow_multiple_solutions = true }

      it "updates all assignments to assignment_status_on_unsolve status only when no accepted solutions remain" do
        assigner = Assigner.new(topic, user)
        result = assigner.assign(user)
        expect(result[:success]).to eq(true)

        DiscourseSolved::AcceptAnswer.call!(params: { post_id: post.id }, guardian: user.guardian)
        expect(topic.assignment.reload.status).to eq("Done")

        DiscourseSolved::AcceptAnswer.call!(params: { post_id: post2.id }, guardian: user.guardian)
        expect(topic.assignment.reload.status).to eq("Done")

        DiscourseSolved::UnacceptAnswer.call!(params: { post_id: post.id }, guardian: user.guardian)
        expect(topic.assignment.reload.status).to eq("Done")

        DiscourseSolved::UnacceptAnswer.call!(
          params: {
            post_id: post2.id,
          },
          guardian: user.guardian,
        )
        expect(topic.assignment.reload.status).to eq("New")
      end
    end

    it "does not update the assignee when a post is accepted" do
      user_2 = Fabricate(:user)
      user_3 = Fabricate(:user)
      group.add(user)
      group.add(user_2)
      group.add(user_3)

      topic_question = Fabricate(:topic, user: user)

      Fabricate(:post, topic: topic_question, user: user)
      Fabricate(:post, topic: topic_question, user: user_2)

      result = Assigner.new(topic_question, user_2).assign(user_2)
      expect(result[:success]).to eq(true)

      post_response = Fabricate(:post, topic: topic_question, user: user_3)
      Assigner.new(post_response, user_3).assign(user_3)

      DiscourseSolved::AcceptAnswer.call!(
        params: {
          post_id: post_response.id,
        },
        guardian: user.guardian,
      )

      expect(topic_question.assignment.assigned_to_id).to eq(user_2.id)
      expect(post_response.assignment.assigned_to_id).to eq(user_3.id)
      DiscourseSolved::UnacceptAnswer.call!(
        params: {
          post_id: post_response.id,
        },
        guardian: user.guardian,
      )

      expect(topic_question.assignment.assigned_to_id).to eq(user_2.id)
      expect(post_response.assignment.assigned_to_id).to eq(user_3.id)
    end

    describe "assigned topic reminder" do
      it "excludes solved topics when ignore_solved_topics_in_assigned_reminder is true" do
        other_topic = Fabricate(:topic_with_op, title: "Topic that should be there")
        other_post = Fabricate(:post, topic: other_topic, user: user)

        other_topic2 = Fabricate(:topic_with_op, title: "Topic that should be there2")
        other_post2 = Fabricate(:post, topic: other_topic2, user: user)

        Assigner.new(other_topic, user).assign(user)
        Assigner.new(other_topic2, user).assign(user)

        reminder = PendingAssignsReminder.new
        topics = reminder.send(:assigned_topics, user, order: :asc)
        expect(topics.to_a.length).to eq(2)

        DiscourseSolved::AcceptAnswer.call!(
          params: {
            post_id: other_post2.id,
          },
          guardian: Discourse.system_user.guardian,
        )
        topics = reminder.send(:assigned_topics, user, order: :asc)
        expect(topics.to_a.length).to eq(2)
        expect(topics).to include(other_topic2)

        SiteSetting.ignore_solved_topics_in_assigned_reminder = true
        topics = reminder.send(:assigned_topics, user, order: :asc)
        expect(topics.to_a.length).to eq(1)
        expect(topics).not_to include(other_topic2)
        expect(topics).to include(other_topic)
      end
    end

    describe "assigned count for user" do
      it "does not count solved topics using assignment_status_on_solve status" do
        SiteSetting.ignore_solved_topics_in_assigned_reminder = true

        other_topic = Fabricate(:topic_with_op, title: "Topic that should be there")
        other_post = Fabricate(:post, topic: other_topic, user: user)

        other_topic2 = Fabricate(:topic_with_op, title: "Topic that should be there2")
        other_post2 = Fabricate(:post, topic: other_topic2, user: user)

        Assigner.new(other_topic, user).assign(user)
        Assigner.new(other_topic2, user).assign(user)

        reminder = PendingAssignsReminder.new
        expect(reminder.send(:assigned_count_for, user)).to eq(2)

        DiscourseSolved::AcceptAnswer.call!(
          params: {
            post_id: other_post2.id,
          },
          guardian: Discourse.system_user.guardian,
        )
        expect(reminder.send(:assigned_count_for, user)).to eq(1)
      end
    end
  end
end

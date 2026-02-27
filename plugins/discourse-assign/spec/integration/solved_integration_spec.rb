# frozen_string_literal: true

RSpec.describe "Solved integration", if: defined?(DiscourseSolved) do
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic: topic) }
  fab!(:user)
  fab!(:group)

  before do
    SiteSetting.solved_enabled = true
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

  describe "updating assignment status on solve" do
    it "updates all assignments to assignment_status_on_solve status when a post is accepted" do
      assigner = Assigner.new(topic, user)
      result = assigner.assign(user)
      expect(result[:success]).to eq(true)

      expect(topic.assignment.status).to eq("New")
      DiscourseSolved.accept_answer!(post, user)
      topic.reload

      expect(topic.solved.answer_post_id).to eq(post.id)
      expect(topic.assignment.reload.status).to eq("Done")
    end

    it "updates all assignments to assignment_status_on_unsolve status when a post is unaccepted" do
      assigner = Assigner.new(topic, user)
      result = assigner.assign(user)
      expect(result[:success]).to eq(true)

      DiscourseSolved.accept_answer!(post, user)

      expect(topic.assignment.reload.status).to eq("Done")

      DiscourseSolved.unaccept_answer!(post)

      expect(topic.assignment.reload.status).to eq("New")
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

      DiscourseSolved.accept_answer!(post_response, user)

      expect(topic_question.assignment.assigned_to_id).to eq(user_2.id)
      expect(post_response.assignment.assigned_to_id).to eq(user_3.id)
      DiscourseSolved.unaccept_answer!(post_response)

      expect(topic_question.assignment.assigned_to_id).to eq(user_2.id)
      expect(post_response.assignment.assigned_to_id).to eq(user_3.id)
    end

    describe "assigned topic reminder" do
      it "excludes solved topics when ignore_solved_topics_in_assigned_reminder is true" do
        other_topic = Fabricate(:topic, title: "Topic that should be there")
        other_post = Fabricate(:post, topic: other_topic, user: user)

        other_topic2 = Fabricate(:topic, title: "Topic that should be there2")
        other_post2 = Fabricate(:post, topic: other_topic2, user: user)

        Assigner.new(other_topic, user).assign(user)
        Assigner.new(other_topic2, user).assign(user)

        reminder = PendingAssignsReminder.new
        topics = reminder.send(:assigned_topics, user, order: :asc)
        expect(topics.to_a.length).to eq(2)

        DiscourseSolved.accept_answer!(other_post2, Discourse.system_user)
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

        other_topic = Fabricate(:topic, title: "Topic that should be there")
        other_post = Fabricate(:post, topic: other_topic, user: user)

        other_topic2 = Fabricate(:topic, title: "Topic that should be there2")
        other_post2 = Fabricate(:post, topic: other_topic2, user: user)

        Assigner.new(other_topic, user).assign(user)
        Assigner.new(other_topic2, user).assign(user)

        reminder = PendingAssignsReminder.new
        expect(reminder.send(:assigned_count_for, user)).to eq(2)

        DiscourseSolved.accept_answer!(other_post2, Discourse.system_user)
        expect(reminder.send(:assigned_count_for, user)).to eq(1)
      end
    end
  end
end

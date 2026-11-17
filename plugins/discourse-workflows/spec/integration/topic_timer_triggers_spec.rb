# frozen_string_literal: true

RSpec.describe "Workflow topic timer triggers" do
  fab!(:admin)
  fab!(:moderator)
  fab!(:category)
  fab!(:destination, :category)
  fab!(:topic) { Fabricate(:topic_with_op, category: category) }

  before { freeze_time }

  it "passes schedule changes only for the selected timer types and categories" do
    workflow =
      create_workflow(
        "trigger:topic_timer_changed",
        "timer_types" => ["publish_to_category"],
        "category_ids" => [category.id],
      )

    timer =
      topic.set_or_create_timer(
        TopicTimer.types[:publish_to_category],
        1.hour.from_now.iso8601,
        by_user: admin,
        category_id: destination.id,
      )
    first_schedule = timer.execute_at
    timer.update!(execute_at: 2.hours.from_now)
    topic.delete_topic_timer(timer.status_type, by_user: admin)
    Fabricate(:topic_timer, topic: topic, user: admin, status_type: TopicTimer.types[:close])
    Fabricate(
      :topic_timer,
      topic: Fabricate(:topic, category: destination),
      user: admin,
      status_type: TopicTimer.types[:publish_to_category],
      category: category,
    )

    payloads = workflow_payloads(workflow)
    expect(payloads.map { |payload| payload["change"] }).to eq(%w[created updated cancelled])
    expect(payloads.first["timer"]).to include(
      "status_type" => "publish_to_category",
      "category_id" => destination.id,
      "user_id" => admin.id,
    )
    expect(payloads.second["previous_timer"]["execute_at"]).to eq(first_schedule.iso8601)
    expect(payloads.map { |payload| payload.dig("topic", "id") }.uniq).to eq([topic.id])
    expect(payloads).to all(
      match_node_output_schema(DiscourseWorkflows::Nodes::TopicTimerChanged::V1),
    )
  end

  it "matches the previous timer type when a publication schedule is replaced" do
    workflow =
      create_workflow(
        "trigger:topic_timer_changed",
        "changes" => ["updated"],
        "timer_types" => ["publish_to_category"],
      )
    timer =
      Fabricate(
        :topic_timer,
        topic: topic,
        user: admin,
        status_type: TopicTimer.types[:publish_to_category],
        category: destination,
      )

    timer.update!(status_type: TopicTimer.types[:close])

    payload = workflow_payloads(workflow).sole
    expect(payload["timer"]["status_type"]).to eq("close")
    expect(payload["previous_timer"]["status_type"]).to eq("publish_to_category")
  end

  it "runs the publication workflow only when the topic is published" do
    workflow = create_workflow("trigger:topic_published", "category_ids" => [destination.id])
    timer =
      Fabricate(
        :topic_timer,
        topic: topic,
        user: admin,
        status_type: TopicTimer.types[:publish_to_category],
        category: destination,
      )
    expect(workflow_payloads(workflow)).to be_empty
    freeze_time(2.hours.from_now)

    Jobs::PublishTopicToCategory.new.execute(topic_timer_id: timer.id)

    payload = workflow_payloads(workflow).sole
    expect(payload["topic"]).to include("id" => topic.id, "category_id" => destination.id)
    expect(payload["published_at"]).to eq(Time.current.iso8601)
    expect(payload).to match_node_output_schema(DiscourseWorkflows::Nodes::TopicPublished::V1)

    job = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last["args"].first
    Jobs::DiscourseWorkflows::ExecuteWorkflow.new.execute(job.symbolize_keys)

    expect(workflow.executions.last.status).to eq("success")
  end

  it "captures the topic after the timer's immediate status change" do
    workflow = create_workflow("trigger:topic_timer_changed", "changes" => ["created"])

    Fabricate(:topic_timer, topic: topic, user: admin, status_type: TopicTimer.types[:open])

    expect(workflow_payloads(workflow).sole.dig("topic", "closed")).to eq(true)
  end

  it "triggers completion for a timer that deletes its topic" do
    workflow =
      create_workflow(
        "trigger:topic_timer_changed",
        "changes" => ["completed"],
        "timer_types" => ["delete"],
      )
    timer =
      Fabricate(:topic_timer, topic: topic, user: admin, status_type: TopicTimer.types[:delete])
    freeze_time(2.hours.from_now)

    Jobs::DeleteTopic.new.execute(topic_timer_id: timer.id)

    payload = workflow_payloads(workflow).sole
    expect(payload.dig("topic", "id")).to eq(topic.id)
    expect(payload).to match_node_output_schema(DiscourseWorkflows::Nodes::TopicTimerChanged::V1)
  end

  it "reports who cancelled or completed a timer on the hidden trigger" do
    workflow = create_workflow("trigger:topic_timer_changed", "changes" => %w[cancelled completed])
    timer = Fabricate(:topic_timer, topic: topic, user: admin)

    topic.delete_topic_timer(timer.status_type, by_user: moderator)

    payload = workflow_payloads(workflow).sole
    expect(payload["actor"]).to include("id" => moderator.id)
    expect(payload).to match_node_output_schema(DiscourseWorkflows::Nodes::TopicTimerChanged::V1)
  end

  describe "Topic timer set" do
    it "runs when a timer is created or rescheduled, with the user who set it" do
      workflow = create_workflow("trigger:topic_timer_set")

      timer =
        topic.set_or_create_timer(TopicTimer.types[:close], 1.hour.from_now.iso8601, by_user: admin)
      topic.set_or_create_timer(TopicTimer.types[:bump], 2.hours.from_now.iso8601, by_user: admin)
      topic.delete_topic_timer(TopicTimer.types[:bump], by_user: admin)

      payloads = workflow_payloads(workflow)
      expect(payloads.map { |payload| payload["change"] }).to eq(%w[created updated])
      expect(payloads.second["timer"]).to include("id" => timer.id, "status_type" => "bump")
      expect(payloads.second["previous_timer"]).to include("status_type" => "close")
      expect(payloads.map { |payload| payload.dig("actor", "id") }).to eq([admin.id, admin.id])
      expect(payloads).to all(
        match_node_output_schema(DiscourseWorkflows::Nodes::TopicTimerSet::V1),
      )
    end

    it "runs as the system user when a reply pushes back a timer based on the last post" do
      topic.set_or_create_timer(
        TopicTimer.types[:close],
        nil,
        by_user: admin,
        based_on_last_post: true,
        duration_minutes: 60,
      )
      workflow = create_workflow("trigger:topic_timer_set")

      freeze_time(10.minutes.from_now)
      PostCreator.create!(Fabricate(:user), topic_id: topic.id, raw: "A reply that pushes it back")

      payload = workflow_payloads(workflow).sole
      expect(payload["change"]).to eq("updated")
      expect(payload["actor"]).to include("id" => Discourse.system_user.id)
    end

    it "runs, and Topic timer completed doesn't, when replies are deleted on schedule" do
      set_workflow = create_workflow("trigger:topic_timer_set")
      completed_workflow = create_workflow("trigger:topic_timer_completed")
      Fabricate(:post, topic: topic)
      timer =
        topic.set_or_create_timer(
          TopicTimer.types[:delete_replies],
          nil,
          by_user: admin,
          duration_minutes: 60,
        )
      Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.clear
      freeze_time(2.hours.from_now)

      Jobs::DeleteReplies.new.execute(topic_timer_id: timer.id)

      payload = workflow_payloads(set_workflow).sole
      expect(payload["timer"]).to include("status_type" => "delete_replies")
      expect(payload["actor"]).to include("id" => Discourse.system_user.id)
      expect(workflow_payloads(completed_workflow)).to be_empty
    end

    it "honours the timer type and category filters" do
      workflow =
        create_workflow(
          "trigger:topic_timer_set",
          "timer_types" => ["bump"],
          "category_ids" => [category.id],
        )
      other_topic = Fabricate(:topic_with_op, category: destination)

      topic.set_or_create_timer(TopicTimer.types[:close], 1.hour.from_now.iso8601, by_user: admin)
      other_topic.set_or_create_timer(
        TopicTimer.types[:bump],
        1.hour.from_now.iso8601,
        by_user: admin,
      )
      expect(workflow_payloads(workflow)).to be_empty

      topic.set_or_create_timer(TopicTimer.types[:bump], 1.hour.from_now.iso8601, by_user: admin)
      expect(workflow_payloads(workflow).sole.dig("topic", "id")).to eq(topic.id)
    end
  end

  describe "Topic timer cleared" do
    it "runs when a moderator removes the timer, with that moderator" do
      workflow = create_workflow("trigger:topic_timer_cleared")
      topic.set_or_create_timer(TopicTimer.types[:close], 1.hour.from_now.iso8601, by_user: admin)

      topic.set_or_create_timer(TopicTimer.types[:close], nil, by_user: moderator)

      payload = workflow_payloads(workflow).sole
      expect(payload["timer"]).to include("status_type" => "close")
      expect(payload["actor"]).to include("id" => moderator.id)
      expect(payload).to match_node_output_schema(DiscourseWorkflows::Nodes::TopicTimerCleared::V1)
    end

    it "runs as the system user when a close timer is dropped because the topic is closed" do
      workflow = create_workflow("trigger:topic_timer_cleared")
      timer = Fabricate(:topic_timer, topic: topic, user: admin)
      topic.update_columns(closed: true)
      freeze_time(2.hours.from_now)

      Jobs::CloseTopic.new.execute(topic_timer_id: timer.id)

      expect(workflow_payloads(workflow).sole["actor"]).to include("id" => Discourse.system_user.id)
    end

    it "doesn't run when the timer is replaced by one of another type" do
      workflow = create_workflow("trigger:topic_timer_cleared")
      topic.set_or_create_timer(TopicTimer.types[:close], 1.hour.from_now.iso8601, by_user: admin)

      topic.set_or_create_timer(TopicTimer.types[:open], 1.hour.from_now.iso8601, by_user: admin)

      expect(workflow_payloads(workflow)).to be_empty
    end
  end

  describe "Topic timer completed" do
    it "runs with the timer's owner when a timer closes its topic" do
      workflow = create_workflow("trigger:topic_timer_completed", "timer_types" => ["close"])
      timer = Fabricate(:topic_timer, topic: topic, user: admin)
      freeze_time(2.hours.from_now)

      Jobs::CloseTopic.new.execute(topic_timer_id: timer.id)

      payload = workflow_payloads(workflow).sole
      expect(payload["actor"]).to include("id" => admin.id)
      expect(payload).to match_node_output_schema(
        DiscourseWorkflows::Nodes::TopicTimerCompleted::V1,
      )
    end

    it "runs as the system user when a timer deletes its topic" do
      workflow = create_workflow("trigger:topic_timer_completed", "timer_types" => ["close"])
      delete_workflow =
        create_workflow("trigger:topic_timer_completed", "timer_types" => ["delete"])
      timer =
        Fabricate(:topic_timer, topic: topic, user: admin, status_type: TopicTimer.types[:delete])
      freeze_time(2.hours.from_now)

      Jobs::DeleteTopic.new.execute(topic_timer_id: timer.id)

      expect(workflow_payloads(workflow)).to be_empty
      payload = workflow_payloads(delete_workflow).sole
      expect(payload.dig("topic", "id")).to eq(topic.id)
      expect(payload["actor"]).to include("id" => Discourse.system_user.id)
    end
  end

  def create_workflow(trigger, parameters = {})
    graph =
      build_workflow_graph do |builder|
        builder.node "trigger", trigger, configuration: parameters
        builder.node "log", "action:log"
        builder.chain "trigger", "log"
      end

    Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
  end

  def workflow_payloads(workflow)
    Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.filter_map do |job|
      args = job["args"].first
      args["trigger_data"] if args["workflow_id"] == workflow.id
    end
  end
end

# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor do
  fab!(:admin)
  fab!(:category)

  before do
    SiteSetting.discourse_workflows_enabled = true
    SiteSetting.tagging_enabled = true
    DiscourseWorkflows::Registry.reset!
    DiscourseWorkflows::Registry.register_trigger(DiscourseWorkflows::Triggers::Manual::V1)
    DiscourseWorkflows::Registry.register_action(DiscourseWorkflows::Actions::CreateTopic::V1)
  end

  after { DiscourseWorkflows::Registry.reset! }

  it "creates a topic from trigger data" do
    workflow = Fabricate(:discourse_workflows_workflow, created_by: admin, enabled: true)

    trigger_node =
      Fabricate(
        :discourse_workflows_node,
        workflow: workflow,
        type: "trigger:manual",
        name: "Manual Trigger",
        position_index: 0,
      )

    action_node =
      Fabricate(
        :discourse_workflows_node,
        workflow: workflow,
        type: "action:create_topic",
        name: "Create Topic",
        position_index: 1,
        configuration: {
          "title" => "={{ trigger.title }}",
          "raw" => "={{ trigger.raw }}",
          "category_id" => "={{ trigger.category_id }}",
          "tag_names" => "={{ trigger.tags }}",
          "user_id" => "={{ trigger.user_id }}",
        },
      )

    Fabricate(
      :discourse_workflows_connection,
      workflow: workflow,
      source_node: trigger_node,
      target_node: action_node,
    )

    trigger_data = {
      title: "Created from workflow",
      raw: "Generated body",
      category_id: category.id,
      tags: %w[alpha beta],
      user_id: admin.id,
    }

    execution = described_class.new(trigger_node, trigger_data).run
    topic = Topic.last

    expect(execution.status).to eq("success")
    expect(topic.title).to eq("Created from workflow")
    expect(topic.first_post.raw).to eq("Generated body")
    expect(topic.category_id).to eq(category.id)
    expect(topic.user_id).to eq(admin.id)
    expect(topic.tags.pluck(:name)).to contain_exactly("alpha", "beta")
    expect(execution.context["Create Topic"].first["json"]).to include(
      "topic_id" => topic.id,
      "topic_title" => topic.title,
      "topic_raw" => "Generated body",
      "user_id" => admin.id,
    )
  end
end

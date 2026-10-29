# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::TopicConvertedToPersonalMessage::V1 do
  fab!(:admin)
  fab!(:tag)
  fab!(:topic) { Fabricate(:topic_with_op, tags: [tag]) }

  before { DiscourseWorkflows::WorkflowDependency.clear_cache! }
  after { DiscourseWorkflows::WorkflowDependency.clear_cache! }

  def publish_workflow(configuration: {})
    graph =
      build_workflow_graph do |g|
        g.node "converted-trigger", "trigger:topic_converted_to_personal_message", configuration:
      end
    workflow = Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
    DiscourseWorkflows::WorkflowDependencyIndexer.call(workflow)
  end

  def trigger_data
    Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.map { |job| job["args"].first["trigger_data"] }
  end

  describe "#output" do
    it "returns the message and the actor" do
      topic.convert_to_private_message(admin)

      output = described_class.new(topic.reload, acting_user: admin).output

      expect(output).to include(
        topic: include(id: topic.id, archetype: Archetype.private_message),
        actor: include(id: admin.id),
      )
      expect(output).to match_node_output_schema(described_class)
    end

    it "returns a null actor when the event carries none" do
      output = described_class.new(topic).output

      expect(output).to include(actor: nil)
      expect(output).to match_node_output_schema(described_class)
    end
  end

  it "runs when a topic is converted, with the user who converted it" do
    publish_workflow

    topic.convert_to_private_message(admin)

    expect(trigger_data.sole).to include(
      "topic" => include("id" => topic.id, "archetype" => Archetype.private_message),
      "actor" => include("id" => admin.id),
    )
  end

  it "only runs for topics with the configured tags" do
    publish_workflow(configuration: { "tag_names" => [tag.name] })
    other_topic = Fabricate(:topic_with_op, tags: [Fabricate(:tag)])

    topic.convert_to_private_message(admin)
    other_topic.convert_to_private_message(admin)

    expect(trigger_data.map { |data| data.dig("topic", "id") }).to eq([topic.id])
  end

  it "doesn't run when the conversion fails" do
    publish_workflow
    SiteSetting.max_allowed_message_recipients = 1
    Fabricate(:post, topic:)

    topic.convert_to_private_message(admin)

    expect(topic.reload.archetype).to eq(Archetype.default)
    expect(trigger_data).to be_empty
  end
end

RSpec.describe DiscourseWorkflows::Nodes::TopicConvertedToPublicTopic::V1 do
  fab!(:admin)
  fab!(:moderator)
  fab!(:category)
  fab!(:pm) { Fabricate(:private_message_post).topic }

  before { DiscourseWorkflows::WorkflowDependency.clear_cache! }
  after { DiscourseWorkflows::WorkflowDependency.clear_cache! }

  def publish_workflow(configuration: {})
    graph =
      build_workflow_graph do |g|
        g.node "converted-trigger", "trigger:topic_converted_to_public_topic", configuration:
      end
    workflow = Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
    DiscourseWorkflows::WorkflowDependencyIndexer.call(workflow)
  end

  def trigger_data
    Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.map { |job| job["args"].first["trigger_data"] }
  end

  describe "#output" do
    it "returns the topic and the actor" do
      pm.convert_to_public_topic(admin, category_id: category.id)

      output = described_class.new(pm.reload, acting_user: admin).output

      expect(output).to include(
        topic: include(id: pm.id, category_id: category.id),
        actor: include(id: admin.id),
      )
      expect(output).to match_node_output_schema(described_class)
    end
  end

  it "runs when a personal message is converted, with the user who converted it" do
    publish_workflow(configuration: { "category_ids" => [category.id] })

    pm.convert_to_public_topic(admin, category_id: category.id)

    expect(trigger_data.sole).to include(
      "topic" => include("id" => pm.id, "category_id" => category.id),
      "actor" => include("id" => admin.id),
    )
  end

  it "doesn't run for topics converted into another category" do
    publish_workflow(configuration: { "category_ids" => [Fabricate(:category).id] })

    pm.convert_to_public_topic(admin, category_id: category.id)

    expect(trigger_data).to be_empty
  end

  it "doesn't run when the revision fails" do
    publish_workflow
    required_tag_group = Fabricate(:tag_group, tags: [Fabricate(:tag)])
    category.category_required_tag_groups.create!(tag_group: required_tag_group, min_count: 1)
    pm.topic_allowed_users.create!(user: moderator)

    pm.convert_to_public_topic(moderator, category_id: category.id)

    expect(pm.reload.archetype).to eq(Archetype.private_message)
    expect(trigger_data).to be_empty
  end
end

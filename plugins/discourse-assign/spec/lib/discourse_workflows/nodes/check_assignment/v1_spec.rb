# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::CheckAssignment::V1 do
  fab!(:user)
  fab!(:other_user, :user)
  fab!(:group)

  before do
    SiteSetting.assign_enabled = true
    SiteSetting.enable_discourse_workflows = true
  end

  describe ".output_schemas" do
    it "merges the assignment result into the input schema" do
      input_schema = {
        "$schema" => DiscourseWorkflows::Schema::DRAFT_URI,
        "type" => "object",
        "properties" => {
          "source" => {
            "type" => "string",
          },
          "is_assigned" => {
            "type" => "string",
          },
        },
      }

      output_schema = described_class.output_schemas({}, input_schemas: [input_schema]).first

      expect(output_schema.dig("properties", "source")).to eq("type" => "string")
      expect(output_schema.dig("properties", "is_assigned")).to eq("type" => "boolean")
    end
  end

  describe "#execute" do
    it "checks user and group topic assignments for each input item", :aggregate_failures do
      user_topic = Fabricate(:topic)
      group_topic = Fabricate(:topic)
      unassigned_topic = Fabricate(:topic)
      Fabricate(:topic_assignment, topic: user_topic, assigned_to: user)
      Fabricate(:topic_assignment, topic: group_topic, assigned_to: group)
      configuration = {
        "target_type" => "topic",
        "topic_id" => "={{ $json.topic_id }}",
        "assignee" => "={{ $json.assignee }}",
      }
      input_items = [
        {
          "json" => {
            "topic_id" => user_topic.id,
            "assignee" => user.username,
            "source" => "user assignment",
          },
        },
        {
          "json" => {
            "topic_id" => group_topic.id,
            "assignee" => group.name,
            "source" => "group assignment",
          },
        },
        {
          "json" => {
            "topic_id" => unassigned_topic.id,
            "assignee" => user.username,
            "source" => "no assignment",
          },
        },
      ]

      output = execute_node_output(configuration:, input_items:).first

      expect(output.map { |item| item["json"]["is_assigned"] }).to eq([true, true, false])
      expect(output.map { |item| item["json"]["source"] }).to eq(
        ["user assignment", "group assignment", "no assignment"],
      )
      expect(output.map { |item| item["pairedItem"] }).to eq(
        [{ "item" => 0 }, { "item" => 1 }, { "item" => 2 }],
      )
      output.each do |item|
        expect(item["json"]).to match_node_output_schema(described_class, configuration:)
      end
    end

    it "returns true for a direct post assignment" do
      post = Fabricate(:post)
      Fabricate(:post_assignment, post:, assigned_to: group)

      result =
        execute_node(
          configuration: {
            "target_type" => "post",
            "post_id" => post.id,
            "assignee" => group.name,
          },
        )

      expect(result["is_assigned"]).to eq(true)
    end

    it "keeps topic and post assignment targets separate", :aggregate_failures do
      topic_with_post_assignment = Fabricate(:topic)
      assigned_post = Fabricate(:post, topic: topic_with_post_assignment)
      Fabricate(:post_assignment, post: assigned_post, assigned_to: user)

      topic_with_topic_assignment = Fabricate(:topic)
      unassigned_post = Fabricate(:post, topic: topic_with_topic_assignment)
      Fabricate(:topic_assignment, topic: topic_with_topic_assignment, assigned_to: user)

      topic_result =
        execute_node(
          configuration: {
            "target_type" => "topic",
            "topic_id" => topic_with_post_assignment.id,
            "assignee" => user.username,
          },
        )
      post_result =
        execute_node(
          configuration: {
            "target_type" => "post",
            "post_id" => unassigned_post.id,
            "assignee" => user.username,
          },
        )

      expect(topic_result["is_assigned"]).to eq(false)
      expect(post_result["is_assigned"]).to eq(false)
    end

    it "returns false for inactive, unmatched, and missing assignments" do
      inactive_topic = Fabricate(:topic)
      unmatched_topic = Fabricate(:topic)
      unassigned_topic = Fabricate(:topic)
      Fabricate(:topic_assignment, topic: inactive_topic, assigned_to: user, active: false)
      Fabricate(:topic_assignment, topic: unmatched_topic, assigned_to: user)
      configuration = {
        "target_type" => "topic",
        "topic_id" => "={{ $json.topic_id }}",
        "assignee" => "={{ $json.assignee }}",
      }
      input_items = [
        { "json" => { "topic_id" => inactive_topic.id, "assignee" => user.username } },
        { "json" => { "topic_id" => unmatched_topic.id, "assignee" => other_user.username } },
        { "json" => { "topic_id" => unassigned_topic.id, "assignee" => user.username } },
      ]

      output = execute_node_output(configuration:, input_items:).first

      expect(output.map { |item| item["json"]["is_assigned"] }).to eq([false, false, false])
    end

    it "raises for invalid target types and missing records", :aggregate_failures do
      expect do
        execute_node(configuration: { "target_type" => "category", "assignee" => user.username })
      end.to raise_error(
        DiscourseWorkflows::NodeError,
        I18n.t(
          "discourse_assign.discourse_workflows.check_assignment.unknown_target_type",
          target_type: "category",
        ),
      )

      expect do
        execute_node(
          configuration: {
            "target_type" => "topic",
            "topic_id" => -1,
            "assignee" => user.username,
          },
        )
      end.to raise_error(ActiveRecord::RecordNotFound)

      expect do
        execute_node(
          configuration: {
            "target_type" => "topic",
            "topic_id" => Fabricate(:topic).id,
            "assignee" => "missing-assignee",
          },
        )
      end.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end

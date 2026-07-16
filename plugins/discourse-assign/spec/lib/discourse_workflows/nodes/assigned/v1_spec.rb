# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Assigned::V1 do
  fab!(:post)
  fab!(:topic) { post.topic }
  fab!(:assigned_by_user, :admin)
  fab!(:assignee, :moderator)
  fab!(:group)

  before do
    SiteSetting.assign_enabled = true
    SiteSetting.enable_discourse_workflows = true
  end

  describe "#valid?" do
    it "returns true when an assignment is present" do
      assignment =
        Fabricate(
          :post_assignment,
          post:,
          assigned_to: assignee,
          assigned_by_user: assigned_by_user,
        )

      expect(described_class.new(assignment)).to be_valid
    end

    it "returns false when assignment is nil" do
      expect(described_class.new(nil)).not_to be_valid
    end
  end

  describe "#output" do
    it "returns assignment, post, topic, and assignee data for post assignments",
       :aggregate_failures do
      assignment =
        Fabricate(
          :post_assignment,
          post: post,
          assigned_to: assignee,
          assigned_by_user: assigned_by_user,
          note: "Please handle this",
          status: "In Progress",
        )

      output = described_class.new(assignment).output

      expect(output[:assignment]).to include(
        id: assignment.id,
        target_type: "Post",
        target_id: post.id,
        topic_id: topic.id,
        topic_assignment: false,
        assigned_to_id: assignee.id,
        assigned_to_type: "User",
        note: "Please handle this",
        status: "In Progress",
      )
      expect(output[:assignment][:assigned_to][:type]).to eq("user")
      expect(output[:assignment][:assigned_to][:user][:username]).to eq(assignee.username)
      expect(output[:assignment][:assigned_by_user][:username]).to eq(assigned_by_user.username)
      expect(output[:post][:id]).to eq(post.id)
      expect(output[:topic][:id]).to eq(topic.id)
      expect(output).to match_node_output_schema(described_class)
    end

    it "uses the topic first post for topic assignments", :aggregate_failures do
      assignment =
        Fabricate(:topic_assignment, topic:, assigned_to: group, assigned_by_user: assigned_by_user)

      output = described_class.new(assignment).output

      expect(output[:assignment]).to include(
        target_type: "Topic",
        target_id: topic.id,
        topic_assignment: true,
        assigned_to_type: "Group",
      )
      expect(output[:assignment][:assigned_to][:type]).to eq("group")
      expect(output[:assignment][:assigned_to][:group][:name]).to eq(group.name)
      expect(output[:post][:id]).to eq(topic.first_post.id)
      expect(output).to match_node_output_schema(described_class)
    end
  end

  describe "#matches?" do
    fab!(:post_assignment) do
      Fabricate(:post_assignment, post:, assigned_to: assignee, assigned_by_user: assigned_by_user)
    end
    fab!(:topic_assignment) do
      Fabricate(
        :topic_assignment,
        topic:,
        assigned_to: assignee,
        assigned_by_user: assigned_by_user,
      )
    end

    it "matches all assignments by default" do
      expect(described_class.new(post_assignment).matches?(trigger_context({}))).to eq(true)
      expect(described_class.new(topic_assignment).matches?(trigger_context({}))).to eq(true)
    end

    it "matches only topic assignments when configured" do
      context = trigger_context("topic_assignments_only" => true)

      expect(described_class.new(post_assignment).matches?(context)).to eq(false)
      expect(described_class.new(topic_assignment).matches?(context)).to eq(true)
    end
  end

  def trigger_context(parameters)
    DiscourseWorkflows::TriggerNodeContext.new({ "parameters" => parameters })
  end
end

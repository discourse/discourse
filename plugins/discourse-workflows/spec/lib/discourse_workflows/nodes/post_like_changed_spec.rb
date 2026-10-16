# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::PostLikeChanged::V1 do
  fab!(:admin)
  fab!(:category)
  fab!(:other_category, :category)
  fab!(:topic) { Fabricate(:topic, category:) }
  fab!(:post) { Fabricate(:post, topic:) }
  fab!(:liker, :user)
  fab!(:tag)

  describe "#matches?" do
    it "filters changes, categories, tags, and topics" do
      SiteSetting.tagging_enabled = true
      topic.tags << tag
      trigger = described_class.from_event(:like_created, PostAction.new(post:, user: liker))

      expect(trigger.matches?(trigger_context({}))).to eq(true)
      expect(trigger.matches?(trigger_context(changes: ["unliked"]))).to eq(false)
      expect(trigger.matches?(trigger_context(category_ids: [other_category.id]))).to eq(false)
      expect(trigger.matches?(trigger_context(tag_names: ["missing"]))).to eq(false)
      expect(trigger.matches?(trigger_context(topic_ids: [topic.id + 1]))).to eq(false)
      expect(
        trigger.matches?(
          trigger_context(
            changes: ["liked"],
            category_ids: [category.id],
            tag_names: [tag.name],
            topic_ids: [topic.id],
          ),
        ),
      ).to eq(true)
    end
  end

  describe "event dispatch" do
    it "runs workflows as the liker when a post is liked and unliked" do
      graph = build_workflow_graph { |builder| builder.node "like", described_class.identifier }
      Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)

      PostActionCreator.like(liker, post)
      PostActionDestroyer.destroy(liker, post, :like)

      jobs = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.map { |job| job["args"].first }
      data = jobs.pluck("trigger_data")
      expect(data.pluck("change")).to eq(%w[liked unliked])
      expect(data.map { |payload| payload.dig("user", "id") }).to eq([liker.id, liker.id])
      expect(jobs.pluck("user_id")).to eq([liker.id, liker.id])
      expect(data).to all(match_node_output_schema(described_class))
    end
  end
end

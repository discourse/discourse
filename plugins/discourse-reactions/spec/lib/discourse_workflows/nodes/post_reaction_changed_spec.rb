# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::PostReactionChanged::V1, discourse_workflows: true do
  fab!(:admin)
  fab!(:category)
  fab!(:other_category, :category)
  fab!(:topic) { Fabricate(:topic, category:) }
  fab!(:post) { Fabricate(:post, topic:) }
  fab!(:reactor, :user)
  fab!(:tag)

  before do
    SiteSetting.discourse_reactions_enabled = true
    SiteSetting.discourse_reactions_enabled_reactions = "laughing|hugs"
  end

  def react(reaction)
    DiscourseReactions::ReactionManager.new(reaction_value: reaction, user: reactor, post:).toggle!
  end

  describe "#matches?" do
    it "filters changes, reactions, categories, tags, and topics" do
      SiteSetting.tagging_enabled = true
      topic.tags << tag
      react("hugs")
      trigger = described_class.new(post, reactor, "laughing")

      expect(trigger.matches?(trigger_context({}))).to eq(true)
      expect(trigger.matches?(trigger_context(changes: ["removed"]))).to eq(false)
      expect(trigger.matches?(trigger_context(reaction: "clap"))).to eq(false)
      expect(trigger.matches?(trigger_context(category_ids: [other_category.id]))).to eq(false)
      expect(trigger.matches?(trigger_context(tag_names: ["missing"]))).to eq(false)
      expect(trigger.matches?(trigger_context(topic_ids: [topic.id + 1]))).to eq(false)
      expect(
        trigger.matches?(
          trigger_context(
            changes: ["replaced"],
            topic_ids: [topic.id],
            reaction: ":laughing:",
            category_ids: [category.id],
            tag_names: [tag.name],
          ),
        ),
      ).to eq(true)
    end
  end

  describe "event dispatch" do
    it "runs workflows as the reacting user when reactions are added, replaced and removed" do
      graph = build_workflow_graph { |builder| builder.node "reaction", described_class.identifier }
      Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)

      %w[laughing hugs hugs].each { |reaction| react(reaction) }

      jobs = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.map { |job| job["args"].first }
      data = jobs.pluck("trigger_data")
      expect(data.map { |payload| payload.slice("change", "reaction", "previous_reaction") }).to eq(
        [
          { "change" => "added", "reaction" => "laughing", "previous_reaction" => nil },
          { "change" => "replaced", "reaction" => "hugs", "previous_reaction" => "laughing" },
          { "change" => "removed", "reaction" => nil, "previous_reaction" => "hugs" },
        ],
      )
      expect(jobs.pluck("user_id").uniq).to eq([reactor.id])
      expect(data).to all(match_node_output_schema(described_class))
    end
  end
end

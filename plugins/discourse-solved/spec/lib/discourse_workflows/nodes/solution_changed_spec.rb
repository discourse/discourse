# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::SolutionChanged::V1, discourse_workflows: true do
  fab!(:admin)
  fab!(:category)
  fab!(:other_category, :category)
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:post) { Fabricate(:post, topic: topic) }
  fab!(:tag)

  before do
    SiteSetting.solved_enabled = true
    SiteSetting.allow_solved_on_all_topics = true
    SiteSetting.tagging_enabled = true
  end

  describe "#matches?" do
    it "filters changes, categories, and tags" do
      post.topic.tags << tag
      trigger = described_class.from_event(:accepted_solution, post)

      expect(trigger.matches?(trigger_context({}))).to eq(true)
      expect(trigger.matches?(trigger_context(changes: ["removed"]))).to eq(false)
      expect(trigger.matches?(trigger_context(category_ids: [other_category.id]))).to eq(false)
      expect(trigger.matches?(trigger_context(tag_names: ["missing"]))).to eq(false)
      expect(
        trigger.matches?(
          trigger_context(
            changes: ["accepted"],
            category_ids: [category.id],
            tag_names: [tag.name],
          ),
        ),
      ).to eq(true)
    end
  end

  describe "event dispatch" do
    it "announces answer removal even when another accepted solution remains" do
      SiteSetting.solved_allow_multiple_solutions = true
      answer = Fabricate(:post, topic: post.topic)
      other_answer = Fabricate(:post, topic: post.topic)
      graph = build_workflow_graph { |builder| builder.node "solution", described_class.identifier }
      Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)

      DiscourseSolved::AcceptAnswer.call(params: { post_id: answer.id }, guardian: admin.guardian)
      DiscourseSolved::AcceptAnswer.call(
        params: {
          post_id: other_answer.id,
        },
        guardian: admin.guardian,
      )
      DiscourseSolved::UnacceptAnswer.call(params: { post_id: answer.id }, guardian: admin.guardian)

      data =
        Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.map do |job|
          job["args"].first["trigger_data"]
        end
      expect(data.pluck("change")).to eq(%w[accepted accepted removed])
      expect(data.map { |payload| payload.dig("post", "id") }).to eq(
        [answer.id, other_answer.id, answer.id],
      )
      expect(data.map { |payload| payload.dig("topic", "id") }.uniq).to eq([topic.id])
      expect(data).to all(match_node_output_schema(described_class))
      expect(post.topic.reload.topic_answers.pluck(:answer_post_id)).to eq([other_answer.id])
    end

    it "stops dispatching when Solved is disabled" do
      graph = build_workflow_graph { |builder| builder.node "solution", described_class.identifier }
      Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
      SiteSetting.solved_enabled = false

      DiscourseEvent.trigger(:accepted_solution, post)

      expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs).to be_empty
      expect(DiscourseWorkflows::Registry.find_node_type(described_class.identifier)).to be_nil
    end
  end

  def trigger_context(parameters)
    DiscourseWorkflows::TriggerNodeContext.new({ "parameters" => parameters.deep_stringify_keys })
  end
end

# frozen_string_literal: true

RSpec.describe "Topic received vote workflow trigger" do
  fab!(:voter, :user)
  fab!(:category)
  fab!(:other_category, :category)
  fab!(:topic) { Fabricate(:topic, category: category) }

  before do
    SiteSetting.topic_voting_enabled = true
    SiteSetting.enable_discourse_workflows = true
    DiscourseTopicVoting::CategorySetting.create!(category: category)
    Category.reset_voting_cache
  end

  it "enqueues matching workflows when a topic is voted on" do
    all_categories_workflow =
      Fabricate(
        :discourse_workflows_workflow,
        created_by: voter,
        published: true,
        **build_workflow_graph { |graph| graph.node "trigger-all", "trigger:topic_received_vote" },
      )
    matching_category_workflow =
      Fabricate(
        :discourse_workflows_workflow,
        created_by: voter,
        published: true,
        **build_workflow_graph do |graph|
          graph.node "trigger-matching",
                     "trigger:topic_received_vote",
                     configuration: {
                       "category_ids" => [category.id],
                     }
        end,
      )
    Fabricate(
      :discourse_workflows_workflow,
      created_by: voter,
      published: true,
      **build_workflow_graph do |graph|
        graph.node "trigger-other",
                   "trigger:topic_received_vote",
                   configuration: {
                     "category_ids" => [other_category.id],
                   }
      end,
    )

    DiscourseTopicVoting::Votes::Cast.call(params: { topic_id: topic.id }, guardian: voter.guardian)

    jobs =
      Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.select do |job|
        job["args"].first["trigger_node_id"].in?(%w[trigger-all trigger-matching trigger-other])
      end

    expect(jobs.map { |job| job["args"].first["workflow_id"] }).to contain_exactly(
      all_categories_workflow.id,
      matching_category_workflow.id,
    )
    expect(jobs.map { |job| job["args"].first["trigger_data"] }).to all(
      include(
        "topic" => include("id" => topic.id),
        "user" => include("id" => voter.id),
        "vote" => include("count" => 1),
      ),
    )
  end
end

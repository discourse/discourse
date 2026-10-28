# frozen_string_literal: true

RSpec.describe "Filter review queue by workflow" do
  include ThemeScreenshotMarker

  fab!(:admin)
  fab!(:llm, :llm_model)
  fab!(:agent) do
    Fabricate(
      :ai_agent,
      default_llm: llm,
      response_format: [{ "key" => "verdict", "type" => "string" }],
    )
  end

  let(:editor_page) { PageObjects::Pages::DiscourseWorkflows::WorkflowEditor.new }
  let(:review_index_page) { PageObjects::Pages::ReviewIndex.new }
  let(:review_page) { PageObjects::Pages::Review.new }

  before do
    SiteSetting.discourse_ai_enabled = true
    SiteSetting.external_system_avatars_url = "/images/avatar.png"
    GlobalSetting.stubs(:smtp_address).returns("smtp.example.com")
    sign_in(admin)
  end

  it "lets an admin find an AI workflow's flagged post by its defined name" do
    graph =
      build_workflow_graph do |builder|
        builder.node "trigger", "trigger:post_created", name: "Post created"
        builder.node "classify",
                     "action:ai_agent",
                     name: "AI Agent",
                     configuration: {
                       "agent_id" => agent.id,
                       "prompt" => "={{ $trigger.post.raw }}",
                     }
        builder.node "condition",
                     "condition:if",
                     name: "If",
                     configuration: {
                       "conditions" => [
                         {
                           "leftValue" => "={{ $json.verdict }}",
                           "rightValue" => "reject",
                           "operator" => {
                             "type" => "string",
                             "operation" => "equals",
                           },
                         },
                       ],
                     }
        builder.node "flag",
                     "action:flag_post",
                     name: "Flag post",
                     configuration: {
                       "post_id" => "={{ $trigger.post.id }}",
                       "flag_type" => "review",
                     }
        builder.chain "trigger", "classify", "condition", "flag"
      end
    workflow_name = "AI content review"
    workflow =
      Fabricate(:discourse_workflows_workflow, created_by: admin, name: workflow_name, **graph)

    editor_page.visit(workflow.id)
    expect(editor_page).to have_name(workflow_name)
    editor_page.publish
    editor_page.visit(workflow.id)
    expect(editor_page).to have_name(workflow_name)
    expect(editor_page).to have_node_count(4)
    expect(editor_page).to have_connection_count(3)
    screenshot_marker(label: "workflow-review-name", only: :desktop)

    post = create_post(title: "Community guidelines", raw: "This post needs a moderator's review.")
    DiscourseAi::Completions::Llm.with_prepared_responses([{ verdict: "reject" }.to_json]) do
      Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.each do |job|
        Jobs::DiscourseWorkflows::ExecuteWorkflow.new.execute(job["args"].first.symbolize_keys)
      end
    end
    reviewable = ReviewablePost.pending.find_by!(target: post)
    Fabricate(:reviewable_flagged_post)

    review_index_page.visit
    review_index_page.expand_filters
    review_index_page.filter_by_type("Workflows").filter_by_reason(workflow_name)
    review_index_page.submit_filters

    expect(review_index_page).to have_reason(workflow_name)
    expect(review_page).to have_reviewables([reviewable])
    screenshot_marker(label: "workflow-review-queue", only: :desktop)
  end
end

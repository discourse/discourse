# frozen_string_literal: true

RSpec.describe "Agent attribution on workflow flags" do
  fab!(:llm, :llm_model)
  fab!(:spam_agent) do
    Fabricate(
      :ai_agent,
      name: "Spam detection",
      default_llm: llm,
      response_format: [{ key: "verdict", type: "string" }],
    )
  end
  fab!(:billing_agent) do
    Fabricate(
      :ai_agent,
      name: "Billing <review>",
      default_llm: llm,
      response_format: [{ key: "verdict", type: "string" }],
    )
  end
  fab!(:pii_agent) do
    Fabricate(
      :ai_agent,
      name: "PII detection",
      default_llm: llm,
      response_format: [{ key: "verdict", type: "string" }],
    )
  end

  before { SiteSetting.discourse_ai_enabled = true }

  it "preserves agent attribution after a timed wait resumes" do
    graph =
      build_workflow_graph do |builder|
        builder.node "trigger", "trigger:manual"
        builder.node "agent",
                     "action:ai_agent",
                     configuration: {
                       agent_id: spam_agent.id,
                       prompt: "Check spam",
                     }
        builder.node "wait",
                     "flow:wait",
                     configuration: {
                       resume: "time_interval",
                       wait_amount: 1,
                       wait_unit: "seconds",
                     }
        builder.node "flag",
                     "action:flag_post",
                     configuration: {
                       post_id: "={{ $trigger.post_id }}",
                       flag_type: "review",
                     }
        builder.chain "trigger", "agent", "wait", "flag"
      end
    workflow =
      Fabricate(:discourse_workflows_workflow, name: "Moderation", published: true, **graph)
    post = Fabricate(:post)
    execution =
      DiscourseAi::Completions::Llm.with_prepared_responses([{ verdict: "yes" }.to_json]) do
        DiscourseWorkflows::Executor.new(workflow, "trigger", { post_id: post.id }).run
      end
    expect(execution.status).to eq("waiting")

    freeze_time(execution.waiting_until + 1.second) do
      Jobs::DiscourseWorkflows::ResumeWaitingExecution.new.execute(
        execution_id: execution.id,
        resume_token: execution.resume_token,
      )
    end

    expect(execution.reload.status).to eq("success")
    expect(ReviewablePost.find_by!(target: post).reviewable_scores.last.reason).to eq(
      I18n.t(
        "discourse_workflows.flag_post.flagged_by_agent",
        agent_name: spam_agent.name,
        workflow_name: workflow.name,
      ),
    )
  end

  it "keeps workflow attribution when two agents contribute to a merged item" do
    graph =
      build_workflow_graph do |builder|
        builder.node "trigger", "trigger:manual"
        builder.node "spam",
                     "action:ai_agent",
                     configuration: {
                       agent_id: spam_agent.id,
                       prompt: "Check spam",
                     }
        builder.node "billing",
                     "action:ai_agent",
                     configuration: {
                       agent_id: billing_agent.id,
                       prompt: "Check billing",
                     }
        builder.node "merge", "flow:merge", configuration: { mode: "combine" }
        builder.node "flag",
                     "action:flag_post",
                     configuration: {
                       post_id: "={{ $trigger.post_id }}",
                       flag_type: "review",
                     }
        builder.connect "trigger", "spam"
        builder.connect "trigger", "billing"
        builder.connect "spam", "merge", input: "input_1"
        builder.connect "billing", "merge", input: "input_2"
        builder.connect "merge", "flag"
      end
    workflow =
      Fabricate(:discourse_workflows_workflow, name: "Moderation", published: true, **graph)
    post = Fabricate(:post)
    execution =
      DiscourseAi::Completions::Llm.with_prepared_responses(
        Array.new(2) { { verdict: "yes" }.to_json },
      ) { DiscourseWorkflows::Executor.new(workflow, "trigger", { post_id: post.id }).run }

    expect(execution.status).to eq("success")
    expect(ReviewablePost.find_by!(target: post).reviewable_scores.last.reason).to eq(
      I18n.t("discourse_workflows.flag_post.flagged_by_workflow", workflow_name: workflow.name),
    )
  end

  it "adds the agent attribution to a flagged user's provenance note" do
    graph =
      build_workflow_graph do |builder|
        builder.node "trigger", "trigger:manual"
        builder.node "agent",
                     "action:ai_agent",
                     configuration: {
                       agent_id: spam_agent.id,
                       prompt: "Check user",
                     }
        builder.node "flag",
                     "action:flag_user",
                     configuration: {
                       username: "={{ $trigger.username }}",
                     }
        builder.chain "trigger", "agent", "flag"
      end
    workflow =
      Fabricate(:discourse_workflows_workflow, name: "Moderation", published: true, **graph)
    user = Fabricate(:user)
    execution =
      DiscourseAi::Completions::Llm.with_prepared_responses([{ verdict: "yes" }.to_json]) do
        DiscourseWorkflows::Executor.new(workflow, "trigger", { username: user.username }).run
      end

    expect(execution.status).to eq("success")
    expect(ReviewableUser.find_by!(target: user).reviewable_notes.last.content).to eq(
      I18n.t(
        "discourse_workflows.flag_user.flagged_by_agent",
        agent_name: spam_agent.name,
        workflow_name: workflow.name,
      ),
    )
  end

  it "attributes each flag to the nearest agent through the executed condition branches" do
    graph =
      build_workflow_graph do |builder|
        builder.node "trigger", "trigger:manual"
        [spam_agent, billing_agent, pii_agent].each_with_index do |agent, index|
          builder.node "agent-#{index}",
                       "action:ai_agent",
                       name: "Agent #{index}",
                       configuration: {
                         agent_id: agent.id,
                         prompt: "Classify this post",
                       }
          builder.node "if-#{index}",
                       "condition:if",
                       configuration: {
                         conditions: [
                           {
                             leftValue: "={{ $json.verdict }}",
                             rightValue: "yes",
                             operator: {
                               type: "string",
                               operation: "equals",
                             },
                           },
                         ],
                       }
          builder.node "flag-#{index}",
                       "action:flag_post",
                       configuration: {
                         post_id: "={{ $trigger.post_id }}",
                         flag_type: index.zero? ? "spam" : "review",
                       }
          builder.connect "agent-#{index}", "if-#{index}"
          builder.connect "if-#{index}", "flag-#{index}", output: "true"
        end
        builder.connect "if-0", "agent-1", output: "false"
        builder.connect "if-1", "agent-2", output: "false"
        builder.connect "trigger", "agent-0"
      end
    workflow =
      Fabricate(:discourse_workflows_workflow, name: "Moderation", published: true, **graph)

    [spam_agent, billing_agent, pii_agent].each_with_index do |agent, index|
      post = Fabricate(:post)
      responses = Array.new(index) { { verdict: "no" }.to_json } + [{ verdict: "yes" }.to_json]
      execution =
        DiscourseAi::Completions::Llm.with_prepared_responses(responses) do
          DiscourseWorkflows::Executor.new(workflow, "trigger", { post_id: post.id }).run
        end

      expect(execution.status).to eq("success")
      score = Reviewable.find_by!(target: post).reviewable_scores.last
      expect(score.reason).to eq(
        I18n.t(
          "discourse_workflows.flag_post.flagged_by_agent",
          agent_name: ERB::Util.html_escape(agent.name),
          workflow_name: workflow.name,
        ),
      )
      expect(score.context).to eq("discourse_workflows:workflow:#{workflow.id}")
    end
  end
end

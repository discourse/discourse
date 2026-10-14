# frozen_string_literal: true

RSpec.describe ReviewablesController do
  fab!(:admin)
  fab!(:workflow, :discourse_workflows_workflow)
  fab!(:other_workflow, :discourse_workflows_workflow)
  fab!(:post_reviewable, :reviewable_flagged_post)
  fab!(:user_reviewable, :reviewable_user)
  fab!(:unrelated_reviewable, :reviewable_queued_post)

  describe "#index" do
    before do
      sign_in(admin)
      post_reviewable.add_score(
        Discourse.system_user,
        ReviewableScore.types[:needs_approval],
        context: "discourse_workflows:workflow:#{workflow.id}",
        force_review: true,
      )
      user_reviewable.add_score(
        Discourse.system_user,
        ReviewableScore.types[:needs_approval],
        context: "discourse_workflows:workflow:#{other_workflow.id}",
        force_review: true,
      )
    end

    def attribute_agents(reviewable, *agents)
      agents.each do |agent|
        DiscourseWorkflows::ReviewableAgent.create!(
          reviewable_id: reviewable.id,
          ai_agent_id: agent.id,
        )
      end
    end

    def listed_reviewable_ids
      response.parsed_body["reviewables"].map { |reviewable| reviewable["id"] }
    end

    def agent_reason_option(agent)
      { "id" => "discourse_workflows:agent:#{agent.id}", "name" => agent.name }
    end

    def agent_filter(agent_id)
      { additional_filters: { workflow_review_agent_id: agent_id }.to_json }
    end

    it "lists queued posts whose payload contains a null character" do
      unrelated_reviewable.update!(
        payload: {
          raw: "stringent restrictions. However, given the \u0000 circumstances",
        },
      )

      get "/review.json", params: { priority: "low", status: "pending", sort_order: "score" }

      expect(response.status).to eq(200)
      expect(listed_reviewable_ids).to include(unrelated_reviewable.id)
    end

    it "offers and filters the attributed agent through both entry points when payloads contain null characters" do
      agent = Fabricate(:ai_agent)
      raw = "Actual null: \u0000. Literal escape: \\u0000. Unicode: café."
      user_reviewable.update!(payload: { raw: raw })
      unrelated_reviewable.update!(payload: { raw: "unrelated \u0000" })
      attribute_agents(user_reviewable, agent)

      [
        {
          type: "discourse_workflows:workflow",
          score_type: "discourse_workflows:agent:#{agent.id}",
        },
        { type: "discourse_workflows:workflow" }.merge(agent_filter(agent.id)),
      ].each do |params|
        get "/review.json", params: params

        expect(response.status).to eq(200)
        expect(response.parsed_body.dig("meta", "score_types")).to include(
          agent_reason_option(agent),
        )
        expect(listed_reviewable_ids).to eq([user_reviewable.id])
      end

      expect(user_reviewable.reload.payload["raw"]).to eq(raw)
    end

    it "offers and filters a built-in agent with a negative ID through both entry points" do
      agent = AiAgent.find(DiscourseAi::Agents::Agent.system_agents[DiscourseAi::Agents::General])
      attribute_agents(user_reviewable, agent)

      [
        { score_type: "discourse_workflows:agent:#{agent.id}" },
        agent_filter(agent.id),
      ].each do |params|
        get "/review.json", params: params

        expect(response.status).to eq(200)
        expect(response.parsed_body.dig("meta", "score_types")).to include(
          agent_reason_option(agent),
        )
        expect(listed_reviewable_ids).to eq([user_reviewable.id])
      end
    end

    it "does not treat payload agent IDs as attribution" do
      agent = Fabricate(:ai_agent)
      legacy_reviewable =
        Fabricate(:reviewable_flagged_post, payload: { workflow_review_agent_ids: [agent.id.to_s] })
      legacy_reviewable.add_score(
        Discourse.system_user,
        ReviewableScore.types[:needs_approval],
        context: "discourse_workflows:workflow:#{workflow.id}",
        force_review: true,
      )

      get "/review.json", params: agent_filter(agent.id)

      expect(response.status).to eq(200)
      expect(listed_reviewable_ids).to be_empty

      get "/review.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body.dig("meta", "score_types")).not_to include(
        agent_reason_option(agent),
      )
    end

    it "adds workflows to Type and current workflow names to Reason" do
      workflow.update!(name: "Renamed workflow")

      get "/review.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body.dig("meta", "reviewable_types")).to include(
        "discourse_workflows:workflow",
      )
      expect(response.parsed_body.dig("meta", "score_types")).to include(
        { "id" => "discourse_workflows:workflow:#{workflow.id}", "name" => workflow.name },
        {
          "id" => "discourse_workflows:workflow:#{other_workflow.id}",
          "name" => other_workflow.name,
        },
      )
    end

    it "offers successfully attributed agents and filters posts and users after an agent rename" do
      agent = Fabricate(:ai_agent)
      other_agent = Fabricate(:ai_agent)
      attribute_agents(post_reviewable, agent)
      attribute_agents(user_reviewable, agent, other_agent)
      agent.update!(name: "Renamed agent")

      get "/review.json", params: { score_type: "discourse_workflows:agent:#{agent.id}" }

      expect(response.status).to eq(200)
      expect(response.parsed_body.dig("meta", "score_types")).to include(
        agent_reason_option(agent),
        agent_reason_option(other_agent),
      )
      expect(listed_reviewable_ids).to contain_exactly(post_reviewable.id, user_reviewable.id)

      get "/review.json",
          params: {
            type: "discourse_workflows:workflow",
            score_type: "discourse_workflows:agent:#{other_agent.id}",
          }

      expect(response.status).to eq(200)
      expect(listed_reviewable_ids).to eq([user_reviewable.id])

      SiteSetting.enable_discourse_workflows = false
      get "/review.json"

      expect(response.parsed_body.dig("meta", "score_types")).not_to include(
        agent_reason_option(agent),
      )
    end

    it "offers and filters an attributed agent for reviewables in any status" do
      agent = Fabricate(:ai_agent)
      attribute_agents(user_reviewable, agent)
      user_reviewable.update!(status: Reviewable.statuses[:approved])

      get "/review.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body.dig("meta", "score_types")).to include(agent_reason_option(agent))

      get "/review.json",
          params: {
            status: "approved",
            score_type: "discourse_workflows:agent:#{agent.id}",
          }

      expect(response.status).to eq(200)
      expect(listed_reviewable_ids).to eq([user_reviewable.id])
    end

    it "hides a deleted agent from Reason but keeps its historical attribution filterable" do
      agent = Fabricate(:ai_agent)
      attribute_agents(user_reviewable, agent)
      agent.destroy!

      get "/review.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body.dig("meta", "score_types")).not_to include(
        agent_reason_option(agent),
      )

      get "/review.json", params: agent_filter(agent.id)

      expect(response.status).to eq(200)
      expect(listed_reviewable_ids).to eq([user_reviewable.id])
    end

    it "ignores attributed agents whose reviewables were bulk-deleted" do
      agent = Fabricate(:ai_agent)
      reviewable = Fabricate(:reviewable_flagged_post)
      attribute_agents(reviewable, agent)
      Reviewable.where(id: reviewable.id).delete_all

      get "/review.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body.dig("meta", "score_types")).not_to include(
        agent_reason_option(agent),
      )

      get "/review.json", params: agent_filter(agent.id)

      expect(response.status).to eq(200)
      expect(listed_reviewable_ids).to be_empty
    end

    it "returns no matches for absent or out-of-range agent IDs" do
      agent = Fabricate(:ai_agent)
      attribute_agents(user_reviewable, agent)

      [
        "9223372036854775807",
        "9223372036854775808",
        "-9223372036854775808",
        "-9223372036854775809",
        "1" * 30,
      ].each do |agent_id|
        get "/review.json", params: agent_filter(agent_id)

        expect(response.status).to eq(200)
        expect(listed_reviewable_ids).to be_empty
      end
    end

    it "ignores malformed agent IDs" do
      [true, [1], { id: 1 }, 0, 1.9, "1 OR 1=1 --"].each do |agent_id|
        get "/review.json", params: agent_filter(agent_id)

        expect(response.status).to eq(200)
        expect(listed_reviewable_ids).to contain_exactly(
          post_reviewable.id,
          user_reviewable.id,
          unrelated_reviewable.id,
        )
      end
    end

    it "filters posts and users by workflow Type" do
      get "/review.json", params: { type: "discourse_workflows:workflow" }

      expect(response.status).to eq(200)
      expect(listed_reviewable_ids).to contain_exactly(post_reviewable.id, user_reviewable.id)
    end

    it "filters by workflow Reason after the workflow is renamed" do
      workflow.update!(name: "Renamed workflow")

      get "/review.json",
          params: {
            type: "discourse_workflows:workflow",
            score_type: "discourse_workflows:workflow:#{workflow.id}",
          }

      expect(response.status).to eq(200)
      expect(listed_reviewable_ids).to eq([post_reviewable.id])

      get "/review.json",
          params: {
            score_type: "discourse_workflows:workflow:#{other_workflow.id}",
          }

      expect(response.status).to eq(200)
      expect(listed_reviewable_ids).to eq([user_reviewable.id])
    end

    it "filters AI workflow flags after moving from AI Automation", :aggregate_failures do
      SiteSetting.discourse_ai_enabled = true
      llm = Fabricate(:llm_model)
      agent =
        Fabricate(
          :ai_agent,
          default_llm: llm,
          response_format: [{ "key" => "verdict", "type" => "string" }],
        )
      automation = Fabricate(:automation, script: "llm_triage")
      graph =
        build_workflow_graph do |graph_builder|
          graph_builder.node "trigger", "trigger:post_created"
          graph_builder.node "classify",
                             "action:ai_agent",
                             configuration: {
                               "agent_id" => agent.id,
                               "prompt" => "={{ $trigger.post.raw }}",
                             }
          graph_builder.node "condition",
                             "condition:if",
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
          graph_builder.node "flag",
                             "action:flag_post",
                             configuration: {
                               "post_id" => "={{ $trigger.post.id }}",
                               "flag_type" => "review",
                             }
          graph_builder.chain "trigger", "classify", "condition", "flag"
        end
      ai_workflow =
        Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
      topic_post = create_post
      Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.clear
      fresh_post = create_post(topic_id: topic_post.topic_id)
      previous_post = create_post(topic_id: topic_post.topic_id)
      job_args =
        Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.map do |job|
          job["args"].first.symbolize_keys
        end

      agent.update!(response_format: [])
      DiscourseAi::Completions::Llm.with_prepared_responses(["bad"]) do
        DiscourseAi::Automation::LlmTriage.handle(
          post: previous_post,
          triage_agent_id: agent.id,
          search_for_text: "bad",
          flag_post: true,
          automation: automation,
        )
      end
      previous_reviewable = ReviewablePost.pending.find_by!(target: previous_post)
      agent.update!(response_format: [{ "key" => "verdict", "type" => "string" }])

      DiscourseAi::Completions::Llm.with_prepared_responses(
        [{ verdict: "reject" }.to_json, { verdict: "reject" }.to_json],
      ) { job_args.each { |args| Jobs::DiscourseWorkflows::ExecuteWorkflow.new.execute(args) } }
      expect(ai_workflow.executions.pluck(:status)).to contain_exactly("success", "success")
      fresh_reviewable = ReviewablePost.pending.find_by!(target: fresh_post)

      get "/review.json",
          params: {
            type: "discourse_workflows:workflow",
            score_type: "discourse_workflows:workflow:#{ai_workflow.id}",
          }

      expect(response.status).to eq(200)
      expect(listed_reviewable_ids).to contain_exactly(fresh_reviewable.id, previous_reviewable.id)

      get "/review.json",
          params: {
            type: "discourse_ai:triage",
            score_type: "ai_triage_automation:#{automation.id}",
          }

      expect(response.status).to eq(200)
      expect(listed_reviewable_ids).to eq([previous_reviewable.id])

      expect do
        DiscourseAi::Completions::Llm.with_prepared_responses([{ verdict: "reject" }.to_json]) do
          Jobs::DiscourseWorkflows::ExecuteWorkflow.new.execute(job_args.last)
        end
      end.not_to change { ReviewableScore.count }
      expect(ai_workflow.executions.pluck(:status)).to contain_exactly(
        "success",
        "success",
        "success",
      )
    end

    it "hides workflow filters when the plugin is disabled" do
      SiteSetting.enable_discourse_workflows = false

      get "/review.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body.dig("meta", "reviewable_types")).not_to include(
        "discourse_workflows:workflow",
      )
      expect(response.parsed_body.dig("meta", "score_types")).not_to include(
        { "id" => "discourse_workflows:workflow:#{workflow.id}", "name" => workflow.name },
      )
    end

    it "ignores malformed workflow IDs" do
      [true, [workflow.id], { id: workflow.id }, 0, 1.9, "1 OR 1=1 --"].each do |workflow_id|
        get "/review.json", params: { additional_filters: { workflow_id: }.to_json }

        expect(response.status).to eq(200)
        expect(listed_reviewable_ids).to contain_exactly(
          post_reviewable.id,
          user_reviewable.id,
          unrelated_reviewable.id,
        )
      end
    end
  end
end

# frozen_string_literal: true

RSpec.describe DiscourseAi::WorkflowUsage do
  fab!(:admin)
  fab!(:workflow) { Fabricate(:discourse_workflows_workflow, created_by: admin) }
  fab!(:other_workflow) { Fabricate(:discourse_workflows_workflow, created_by: admin) }

  before { SiteSetting.discourse_ai_enabled = true }

  it "counts requests, tokens and spending only for the selected workflow and period" do
    Fabricate(
      :ai_api_audit_log,
      feature_name: "workflow",
      feature_context: {
        workflow_id: workflow.id.to_s,
      },
      request_tokens: 100,
      response_tokens: 30,
      cache_read_tokens: 10,
      estimated_cost: 0.0123,
    )
    Fabricate(
      :ai_api_audit_log,
      feature_name: "workflow",
      feature_context: {
        workflow_id: workflow.id.to_s,
      },
      request_tokens: 10,
      response_tokens: 5,
      estimated_cost: 0.002,
    )
    Fabricate(
      :ai_api_audit_log,
      feature_name: "workflow",
      feature_context: {
        workflow_id: other_workflow.id.to_s,
      },
    )
    Fabricate(
      :ai_api_audit_log,
      feature_name: "workflow",
      feature_context: {
        workflow_id: workflow.id.to_s,
      },
      created_at: 8.days.ago,
    )
    Fabricate(:ai_api_audit_log, feature_name: "workflow", feature_context: nil)

    stats =
      DiscourseWorkflows::Stats::Summary.call(
        params: {
          workflow_id: workflow.id,
        },
        guardian: admin.guardian,
      )[
        :stats
      ]

    expect(stats[:ai_usage]).to eq(requests: 2, tokens: 155, estimated_cost: 0.0143)
  end

  it "includes workflow context compression requests but not unrelated compression" do
    compression =
      Fabricate(
        :ai_api_audit_log,
        feature_name: "context_compression",
        feature_context: {
          workflow_id: workflow.id.to_s,
        },
        request_tokens: 70,
        response_tokens: 20,
        estimated_cost: 0.003,
      )
    Fabricate(:ai_api_audit_log, feature_name: "context_compression", request_tokens: 500)

    expect(described_class.workflow_id(compression)).to eq(workflow.id)
    expect(described_class.for(workflow_id: workflow.id, since: 7.days.ago)).to eq(
      requests: 1,
      tokens: 90,
      estimated_cost: 0.003,
    )
    expect(described_class.breakdown(start_date: 7.days.ago, end_date: Time.zone.now)).to eq(
      [{ id: workflow.id, name: workflow.name, requests: 1, tokens: 90, estimated_cost: 0.003 }],
    )
    expect(
      described_class.breakdown(
        start_date: 7.days.ago,
        end_date: Time.zone.now,
        feature: "workflow",
      ),
    ).to eq([])
    expect(
      described_class.breakdown(
        start_date: 7.days.ago,
        end_date: Time.zone.now,
        feature: "context_compression",
      ),
    ).to eq(
      [{ id: workflow.id, name: workflow.name, requests: 1, tokens: 90, estimated_cost: 0.003 }],
    )
  end

  it "omits usage when AI is disabled" do
    SiteSetting.discourse_ai_enabled = false

    stats =
      DiscourseWorkflows::Stats::Summary.call(
        params: {
          workflow_id: workflow.id,
        },
        guardian: admin.guardian,
      )[
        :stats
      ]

    expect(stats).not_to have_key(:ai_usage)
  end

  it "returns zero usage for a workflow with no agent requests" do
    stats =
      DiscourseWorkflows::Stats::Summary.call(
        params: {
          workflow_id: workflow.id,
        },
        guardian: admin.guardian,
      )[
        :stats
      ]

    expect(stats[:ai_usage]).to eq(requests: 0, tokens: 0, estimated_cost: 0.0)
  end
end

# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::WorkflowTestEvaluator do
  def check(effect, mode: "happens", count: 1, conditions: [])
    DiscourseWorkflows::WorkflowTestChecks.normalize(
      [{ effect:, mode:, count:, conditions: }],
    ).first
  end

  def condition(field, value, operator: "equals")
    { field:, operator:, value: }
  end

  let(:pm_effect) do
    { "type" => "personal_message", "fields" => { "recipient" => "sam", "title" => "Welcome" } }
  end

  it "passes when a matching effect happened, with trimmed and case-sensitive equality" do
    result =
      described_class.call(
        checks: [check("personal_message", conditions: [condition("recipient", " sam ")])],
        effects: [pm_effect],
      )
    expect(result["status"]).to eq("passed")

    mismatch =
      described_class.call(
        checks: [check("personal_message", conditions: [condition("recipient", "Sam")])],
        effects: [pm_effect],
      )
    expect(mismatch["status"]).to eq("failed")
    expect(mismatch["reason"]).to include("closest match")
  end

  it "matches contains without regard to case" do
    result =
      described_class.call(
        checks: [
          check(
            "personal_message",
            conditions: [condition("title", "WELCOME", operator: "contains")],
          ),
        ],
        effects: [pm_effect],
      )

    expect(result["status"]).to eq("passed")
  end

  it "reports a missing effect, an unexpected effect and a wrong count" do
    missing = described_class.call(checks: [check("post_created")], effects: [pm_effect])
    unexpected =
      described_class.call(
        checks: [check("personal_message", mode: "not_happens")],
        effects: [pm_effect],
      )
    wrong_count =
      described_class.call(
        checks: [check("personal_message", mode: "count", count: 2)],
        effects: [pm_effect],
      )

    expect(missing["reason"]).to eq("Expected a post, but it would not have happened.")
    expect(unexpected["status"]).to eq("failed")
    expect(wrong_count["reason"]).to eq("Expected 2 personal messages, but 1 would have happened.")
  end

  it "counts duplicates and treats absence as zero" do
    result =
      described_class.call(
        checks: [
          check("personal_message", mode: "count", count: 2),
          check("post_created", mode: "count", count: 0),
        ],
        effects: [pm_effect, pm_effect],
      )

    expect(result["status"]).to eq("passed")
  end

  it "never matches a synthetic id against a literal" do
    effect = { "type" => "post_created", "fields" => { "topic_id" => -1, "raw" => "hi" } }

    result =
      described_class.call(
        checks: [check("post_created", conditions: [condition("topic_id", "-1")])],
        effects: [effect],
      )

    expect(result["status"]).to eq("failed")
  end

  it "fails the finishes check when the workflow stopped at a step" do
    result =
      described_class.call(
        checks: [check("finishes"), check("personal_message")],
        effects: [],
        error_kind: "node",
        failed_step: "Send PM",
        error_message: "boom",
      )

    expect(result["status"]).to eq("failed")
    expect(result["checks"].map { |entry| entry["reason"] }).to eq(
      [
        "The workflow stopped with an error at Send PM: boom",
        "Expected a personal message, but the workflow stopped at Send PM first.",
      ],
    )
  end

  it "could not run for safety, timeout and engine failures" do
    %w[safety timeout engine].each do |kind|
      result =
        described_class.call(
          checks: [check("finishes")],
          effects: [],
          error_kind: kind,
          error_message: "why",
        )

      expect(result).to include("status" => "could_not_run", "reason" => "why", "checks" => [])
    end
  end

  it "passes nothing-happens only when there are no effects" do
    expect(described_class.call(checks: [check("nothing")], effects: [])["status"]).to eq("passed")
    expect(described_class.call(checks: [check("nothing")], effects: [pm_effect])["status"]).to eq(
      "failed",
    )
  end
end

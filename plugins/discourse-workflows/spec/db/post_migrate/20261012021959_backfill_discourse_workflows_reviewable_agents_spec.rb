# frozen_string_literal: true

require Rails.root.join(
          "plugins/discourse-workflows/db/post_migrate/20261012021959_backfill_discourse_workflows_reviewable_agents.rb",
        )

RSpec.describe BackfillDiscourseWorkflowsReviewableAgents do
  fab!(:workflow, :discourse_workflows_workflow)
  fab!(:reviewable, :reviewable_flagged_post)
  fab!(:unrelated_reviewable, :reviewable_queued_post)

  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
    DB.exec("UPDATE schema_migration_details SET created_at = NOW() - INTERVAL '2 hours'")
    Discourse.clear_site_creation_date_cache
    reviewable.add_score(
      Discourse.system_user,
      ReviewableScore.types[:needs_approval],
      context: "discourse_workflows:workflow:#{workflow.id}",
      force_review: true,
    )
  end

  after do
    ActiveRecord::Migration.verbose = @original_verbose
    Discourse.clear_site_creation_date_cache
  end

  it "backfills canonical historical IDs across statuses without reading unrelated payloads" do
    raw = "Actual null: \u0000. Literal escape: \\u0000. Unicode: café."
    payload = {
      raw: raw,
      workflow_review_agent_ids: [
        "42",
        "42",
        "9223372036854775807",
        "9223372036854775808",
        "1" * 100,
        "0",
        "-1",
        "-9223372036854775808",
        "-9223372036854775809",
        "-0",
        "-01",
        "01",
        "garbage",
        43,
        nil,
        {},
      ],
    }
    reviewable.update!(payload: payload, status: Reviewable.statuses[:approved])
    unrelated_reviewable.update!(
      payload: {
        raw: "unrelated \u0000",
        workflow_review_agent_ids: ["99"],
      },
    )
    DiscourseWorkflows::ReviewableAgent.create!(reviewable_id: reviewable.id, ai_agent_id: 42)

    2.times { described_class.new.up }

    expect(
      DiscourseWorkflows::ReviewableAgent.pluck(:reviewable_id, :ai_agent_id),
    ).to contain_exactly(
      [reviewable.id, 42],
      [reviewable.id, -1],
      [reviewable.id, -9_223_372_036_854_775_808],
      [reviewable.id, 9_223_372_036_854_775_807],
    )
    expect(reviewable.reload.payload).to eq(payload.deep_stringify_keys)
  end

  it "skips malformed attribution shapes and continues to later batches" do
    malformed =
      [nil, "42", 42, { id: "42" }].map do |ids|
        record = Fabricate(:reviewable_flagged_post, payload: { workflow_review_agent_ids: ids })
        record.add_score(
          Discourse.system_user,
          ReviewableScore.types[:needs_approval],
          context: "discourse_workflows:workflow:#{workflow.id}",
          force_review: true,
        )
        record
      end
    valid_reviewable =
      Fabricate(:reviewable_flagged_post, payload: { workflow_review_agent_ids: ["42"] })
    valid_reviewable.add_score(
      Discourse.system_user,
      ReviewableScore.types[:needs_approval],
      context: "discourse_workflows:workflow:#{workflow.id}",
      force_review: true,
    )

    stub_const(described_class, :BATCH_SIZE, 2) { described_class.new.up }

    expect(DiscourseWorkflows::ReviewableAgent.pluck(:reviewable_id, :ai_agent_id)).to eq(
      [[valid_reviewable.id, 42]],
    )
    expect(
      DiscourseWorkflows::ReviewableAgent.where(reviewable_id: malformed.map(&:id)),
    ).to be_empty
  end

  it "ignores lookalike workflow score prefixes" do
    unrelated_reviewable.update!(payload: { workflow_review_agent_ids: ["99"] })
    unrelated_reviewable.add_score(
      Discourse.system_user,
      ReviewableScore.types[:needs_approval],
      context: "discourseXworkflows:workflow:#{workflow.id}",
      force_review: true,
    )

    described_class.new.up

    expect(DiscourseWorkflows::ReviewableAgent.count).to eq(0)
  end

  it "skips reviewables deleted after their payloads were read" do
    reviewable.update!(payload: { workflow_review_agent_ids: ["42"] })
    deleted = false
    allow(DB).to receive(:query).and_wrap_original do |query, *args, **kwargs|
      rows = query.call(*args, **kwargs)
      if !deleted
        Reviewable.where(id: reviewable.id).delete_all
        deleted = true
      end
      rows
    end

    described_class.new.up

    expect(DiscourseWorkflows::ReviewableAgent.count).to eq(0)
  end

  it "does not backfill application rows on a fresh install" do
    DB.exec("UPDATE schema_migration_details SET created_at = NOW()")
    Discourse.clear_site_creation_date_cache
    reviewable.update!(payload: { workflow_review_agent_ids: ["42"] })

    described_class.new.up

    expect(DiscourseWorkflows::ReviewableAgent.count).to eq(0)
  end
end

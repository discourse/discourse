# frozen_string_literal: true

require "json"

class BackfillDiscourseWorkflowsReviewableAgents < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  BATCH_SIZE = 1_000
  MIN_BIGINT = -9_223_372_036_854_775_808
  MAX_BIGINT = 9_223_372_036_854_775_807

  def up
    return if !Migration::Helpers.existing_site?

    last_id = 0
    max_id = DB.query_single("SELECT COALESCE(MAX(id), 0) FROM reviewables").first

    loop do
      rows =
        DB.query(
          <<~SQL,
          SELECT reviewables.id, reviewables.payload::text AS raw_payload
          FROM reviewables
          WHERE reviewables.id > :last_id AND reviewables.id <= :max_id
            AND EXISTS (
              SELECT 1
              FROM reviewable_scores
              WHERE reviewable_scores.reviewable_id = reviewables.id
                AND reviewable_scores.context LIKE :workflow_context ESCAPE '!'
            )
          ORDER BY reviewables.id
          LIMIT :batch_size
        SQL
          last_id:,
          max_id:,
          batch_size: BATCH_SIZE,
          workflow_context: "discourse!_workflows:workflow:%",
        )
      break if rows.empty?

      reviewable_ids = []
      agent_ids = []
      rows.each do |row|
        legacy_agent_ids(row.raw_payload).each do |agent_id|
          reviewable_ids << row.id
          agent_ids << agent_id
        end
      end

      DB.exec(<<~SQL, reviewable_ids:, agent_ids:) if agent_ids.present?
          INSERT INTO discourse_workflows_reviewable_agents (reviewable_id, ai_agent_id, created_at)
          SELECT reviewables.id, attribution.ai_agent_id, CURRENT_TIMESTAMP
          FROM unnest(ARRAY[:reviewable_ids]::bigint[], ARRAY[:agent_ids]::bigint[])
            AS attribution(reviewable_id, ai_agent_id)
          INNER JOIN reviewables ON reviewables.id = attribution.reviewable_id
          FOR KEY SHARE OF reviewables
          ON CONFLICT (reviewable_id, ai_agent_id) DO NOTHING
        SQL
      last_id = rows.last.id
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def legacy_agent_ids(raw_payload)
    return [] if raw_payload.nil?

    payload = JSON.parse(raw_payload)
    return [] if !payload.is_a?(Hash)

    ids = payload["workflow_review_agent_ids"]
    return [] if !ids.is_a?(Array)

    ids
      .select do |id|
        id.is_a?(String) && id.length <= 20 && id.match?(/\A-?[1-9][0-9]*\z/) &&
          id.to_i.between?(MIN_BIGINT, MAX_BIGINT)
      end
      .uniq
  rescue JSON::ParserError
    []
  end
end

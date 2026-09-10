# frozen_string_literal: true

class McpActivityReport
  MAX_FILTER_LENGTH = 200
  OUTCOMES = %w[success error rate_limited].freeze

  def initialize(limit:, cursor: nil, filter: nil, outcome: nil)
    @limit = limit
    @cursor = cursor
    @filter = filter.to_s.strip
    @outcome = outcome.presence
  end

  def call
    validate!

    values = activity_relation.limit(limit + 1).to_a
    if values.length > limit
      values.pop
      next_cursor = values.last.id
    end

    result = {
      activity: values.map { |entry| serialize(entry) },
      next_cursor: next_cursor,
      meta: {
        next_cursor: next_cursor,
      },
    }
    result[:metrics] = metrics if cursor.nil?
    result
  end

  private

  attr_reader :limit, :cursor, :filter, :outcome

  def validate!
    raise Discourse::InvalidParameters.new(:filter) if filter.length > MAX_FILTER_LENGTH
    if outcome.present? && !OUTCOMES.include?(outcome)
      raise Discourse::InvalidParameters.new(:outcome)
    end
  end

  def activity_relation
    relation = McpAuditLog.left_joins(:user, :client).preload(:user, :client).order(id: :desc)
    relation = relation.where("mcp_audit_logs.id < ?", cursor) if cursor
    relation = relation.where(outcome: outcome) if outcome

    if filter.present?
      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(filter)}%"
      relation = relation.where(<<~SQL.squish, pattern: pattern, request_id: filter)
            users.username ILIKE :pattern OR
            mcp_oauth_clients.name ILIKE :pattern OR
            mcp_oauth_clients.client_id ILIKE :pattern OR
            mcp_audit_logs.tool ILIKE :pattern OR
            mcp_audit_logs.request_id = :request_id
          SQL
    end

    relation
  end

  def metrics
    tool_calls, errors, rate_limits, p95_latency_ms =
      McpAuditLog.where("occurred_at > ?", 24.hours.ago).pick(
        Arel.sql("COALESCE(SUM(occurrences), 0)::bigint"),
        Arel.sql("COALESCE(SUM(occurrences) FILTER (WHERE outcome <> 'success'), 0)::bigint"),
        Arel.sql("COALESCE(SUM(occurrences) FILTER (WHERE outcome = 'rate_limited'), 0)::bigint"),
        Arel.sql(<<~SQL.squish),
              COALESCE(
                PERCENTILE_DISC(0.95) WITHIN GROUP (ORDER BY duration_ms)
                  FILTER (WHERE duration_ms IS NOT NULL),
                0
              )::integer
            SQL
      )

    {
      tool_calls: tool_calls,
      errors: errors,
      rate_limits: rate_limits,
      p95_latency_ms: p95_latency_ms,
    }
  end

  def serialize(entry)
    {
      id: entry.id,
      occurred_at: entry.occurred_at,
      created_at: entry.occurred_at,
      username: entry.user&.username,
      client_id: entry.client&.client_id,
      client_name: entry.client&.name,
      method: entry[:method],
      tool: entry.tool,
      outcome: entry.outcome,
      http_status: entry.http_status,
      duration_ms: entry.duration_ms,
      request_id: entry.request_id,
      target: entry.target,
      occurrences: entry.occurrences,
    }
  end
end

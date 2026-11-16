# frozen_string_literal: true

class McpActivityReport
  DEFAULT_RANGE_DAYS = 7
  MAX_FILTER_LENGTH = 200
  OUTCOMES = %w[success error rate_limited].freeze

  def initialize(limit:, cursor: nil, end_date: nil, filter: nil, outcome: nil, start_date: nil)
    @limit = limit
    @cursor = cursor
    @end_date = parse_date(end_date, :end_date) || Time.zone.today
    @filter = filter.to_s.strip
    @outcome = outcome.presence
    @start_date = parse_date(start_date, :start_date) || (DEFAULT_RANGE_DAYS - 1).days.ago.to_date
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

  attr_reader :limit, :cursor, :end_date, :filter, :outcome, :start_date

  def validate!
    raise Discourse::InvalidParameters.new(:filter) if filter.length > MAX_FILTER_LENGTH
    if outcome.present? && !OUTCOMES.include?(outcome)
      raise Discourse::InvalidParameters.new(:outcome)
    end
    raise Discourse::InvalidParameters.new(:start_date) if start_date > end_date
  end

  def activity_relation
    relation = filtered_relation.preload(:user, :client).order(id: :desc)
    relation = relation.where("mcp_audit_logs.id < ?", cursor) if cursor

    relation
  end

  def filtered_relation
    relation = McpAuditLog.where(occurred_at: start_date.beginning_of_day..end_date.end_of_day)
    relation = relation.where(outcome: outcome) if outcome

    if filter.present?
      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(filter)}%"
      relation =
        relation.left_joins(:user, :client).where(
          <<~SQL.squish,
          users.username ILIKE :pattern OR
          mcp_oauth_clients.name ILIKE :pattern OR
          mcp_oauth_clients.client_id ILIKE :pattern OR
          mcp_audit_logs.tool ILIKE :pattern OR
          mcp_audit_logs.request_id = :request_id
        SQL
          pattern: pattern,
          request_id: filter,
        )
    end

    relation
  end

  def parse_date(value, parameter)
    return if value.blank?
    raise Discourse::InvalidParameters.new(parameter) if !value.is_a?(String)

    Date.iso8601(value)
  rescue Date::Error
    raise Discourse::InvalidParameters.new(parameter)
  end

  def metrics
    tool_calls, failed_tool_calls, rate_limits, p95_latency_ms =
      filtered_relation.pick(
        Arel.sql(<<~SQL.squish),
          COALESCE(
            SUM(occurrences) FILTER (
              WHERE method = 'tools/call' AND outcome <> 'rate_limited'
            ),
            0
          )::bigint
        SQL
        Arel.sql(<<~SQL.squish),
          COALESCE(
            SUM(occurrences) FILTER (
              WHERE method = 'tools/call' AND outcome = 'error'
            ),
            0
          )::bigint
        SQL
        Arel.sql("COALESCE(SUM(occurrences) FILTER (WHERE outcome = 'rate_limited'), 0)::bigint"),
        Arel.sql(<<~SQL.squish),
              PERCENTILE_DISC(0.95) WITHIN GROUP (ORDER BY duration_ms)
                FILTER (
                  WHERE method = 'tools/call'
                    AND outcome <> 'rate_limited'
                    AND duration_ms IS NOT NULL
                )::integer
            SQL
      )

    {
      tool_calls: tool_calls,
      failed_tool_calls: failed_tool_calls,
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

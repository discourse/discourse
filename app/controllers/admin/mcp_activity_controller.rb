# frozen_string_literal: true

class Admin::McpActivityController < Admin::AdminController
  def index
    limit = fetch_limit_from_params(default: 50, max: 100)
    relation = McpAuditLog.includes(:user, :client).order(id: :desc)
    relation = relation.where("id < ?", params[:cursor].to_i) if params[:cursor].present?
    values = relation.limit(limit + 1).to_a
    if values.length > limit
      values.pop
      next_cursor = values.last.id
    end
    recent = McpAuditLog.where("occurred_at > ?", 24.hours.ago)
    p95_latency_ms =
      recent
        .where.not(duration_ms: nil)
        .pick(Arel.sql("PERCENTILE_DISC(0.95) WITHIN GROUP (ORDER BY duration_ms)"))
    render json: {
             activity: values.map { |entry| serialize(entry) },
             next_cursor: next_cursor,
             meta: {
               next_cursor: next_cursor,
             },
             metrics: {
               calls: recent.sum(:occurrences),
               errors: recent.where.not(outcome: "success").sum(:occurrences),
               rate_limits: recent.where(outcome: "rate_limited").sum(:occurrences),
               p95_latency_ms: p95_latency_ms || 0,
             },
           }
  end

  private

  def serialize(entry)
    {
      id: entry.id,
      occurred_at: entry.occurred_at,
      created_at: entry.occurred_at,
      username: entry.user&.username,
      client_id: entry.client&.client_id,
      client_name: entry.client&.name,
      method: entry[:method],
      capability: entry.capability,
      tool: entry.capability,
      outcome: entry.outcome,
      http_status: entry.http_status,
      duration_ms: entry.duration_ms,
      request_id: entry.request_id,
      target: entry.target,
      occurrences: entry.occurrences,
    }
  end
end

# frozen_string_literal: true

class McpOauthAuthorizationsPage
  MAX_FILTER_LENGTH = 200
  Result = Data.define(:records, :next_cursor)

  def initialize(limit:, cursor: nil, filter: nil)
    @limit = limit
    @cursor = cursor
    @filter = filter.to_s.strip
  end

  def call
    raise Discourse::InvalidParameters.new(:filter) if filter.length > MAX_FILTER_LENGTH

    records = relation.limit(limit + 1).to_a
    if records.length > limit
      records.pop
      next_cursor = records.last.id
    end
    Result.new(records:, next_cursor:)
  end

  private

  attr_reader :limit, :cursor, :filter

  def relation
    records =
      McpOauthAuthorization
        .left_joins(:user, :client, :scope_records)
        .preload(:user, :client, :scope_records, :access_tokens)
        .distinct
        .order(id: :desc)
    records = records.where("mcp_oauth_authorizations.id < ?", cursor) if cursor

    if filter.present?
      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(filter)}%"
      records = records.where(<<~SQL.squish, pattern:)
            users.username ILIKE :pattern OR
            mcp_oauth_clients.name ILIKE :pattern OR
            mcp_oauth_clients.client_id ILIKE :pattern OR
            mcp_oauth_authorizations.status ILIKE :pattern OR
            mcp_oauth_authorization_scopes.name ILIKE :pattern
          SQL
    end

    records
  end
end

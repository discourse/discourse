# frozen_string_literal: true

describe Jobs::CleanUpMcpRecords do
  fab!(:user)

  let(:client) do
    McpOauthClient.create!(
      client_id: "cleanup-spec-client",
      name: "Cleanup spec client",
      registration_type: "pre_registered",
      trust_state: "approved",
      redirect_uris: ["http://127.0.0.1/callback"],
    )
  end

  let(:authorization) do
    McpOauthAuthorization.create!(
      user:,
      client:,
      resource: DiscourseMcp.resource_url,
      consented_at: Time.zone.now,
      status: "active",
    )
  end

  before do
    freeze_time(Time.zone.local(2026, 8, 28, 12))
    SiteSetting.mcp_audit_log_retention_days = 90
  end

  around { |example| stub_const(described_class, :BATCH_SIZE, 2) { example.run } }

  it "deletes every expired batch and keeps records within retention" do
    3.times do
      create_authorization_code(expires_at: 1.minute.ago)
      create_access_token(expires_at: 31.days.ago)
      create_refresh_token(expires_at: 31.days.ago)
      McpAuditLog.create!(occurred_at: 91.days.ago, outcome: "success")
    end

    current_authorization_code = create_authorization_code(expires_at: 1.hour.from_now)
    current_access_token = create_access_token(expires_at: 29.days.ago)
    current_refresh_token = create_refresh_token(expires_at: 29.days.ago)
    current_audit_log = McpAuditLog.create!(occurred_at: 89.days.ago, outcome: "success")

    queries = track_sql_queries { described_class.new.execute({}) }

    expect_delete_batches(queries, "mcp_oauth_authorization_codes", 2)
    expect_delete_batches(queries, "mcp_oauth_access_tokens", 2)
    expect_delete_batches(queries, "mcp_oauth_refresh_tokens", 2)
    expect_delete_batches(queries, "mcp_audit_logs", 2)
    expect(McpOauthAuthorizationCode.all).to contain_exactly(current_authorization_code)
    expect(McpOauthAccessToken.all).to contain_exactly(current_access_token)
    expect(McpOauthRefreshToken.all).to contain_exactly(current_refresh_token)
    expect(McpAuditLog.all).to contain_exactly(current_audit_log)
  end

  def create_authorization_code(expires_at:)
    McpOauthAuthorizationCode.create!(
      authorization:,
      code_hash: SecureRandom.hex,
      code_challenge: "challenge",
      redirect_uri: client.redirect_uris.first,
      resource: DiscourseMcp.resource_url,
      scopes: [],
      grant_version: authorization.grant_version,
      expires_at:,
    )
  end

  def create_access_token(expires_at:)
    McpOauthAccessToken.create!(
      authorization:,
      client:,
      user:,
      token_hash: SecureRandom.hex,
      resource: DiscourseMcp.resource_url,
      scopes: [],
      grant_version: authorization.grant_version,
      expires_at:,
    )
  end

  it "removes dynamically registered apps nobody approved within a day" do
    register = ->(name) do
      registration =
        DiscourseMcp::OAuth::ClientRegistration.register!(
          "client_name" => name,
          "redirect_uris" => ["https://agent.example.com/callback"],
        )
      McpOauthClient.find_by!(client_id: registration[:client_id])
    end
    abandoned = register.("Abandoned")
    approved = register.("Approved")
    edited = register.("Edited")
    blocked = register.("Blocked")
    recent = register.("Recent")
    McpOauthAuthorization.create!(
      user:,
      client: approved,
      resource: DiscourseMcp.resource_url,
      consented_at: Time.zone.now,
      status: "active",
    )
    edited.update_registration!(name: "Named by an admin")
    blocked.update!(trust_state: "blocked")
    McpOauthClient.where(
      id: [abandoned.id, approved.id, edited.id, blocked.id, client.id],
    ).update_all(created_at: 2.days.ago)

    described_class.new.execute({})

    expect(
      McpOauthClient.where(id: [abandoned.id, approved.id, edited.id, blocked.id, recent.id]).pluck(
        :name,
      ),
    ).to contain_exactly("Approved", "Named by an admin", "Blocked", "Recent")
    expect(McpOauthClient.exists?(client.id)).to eq(true)
  end

  def create_refresh_token(expires_at:)
    McpOauthRefreshToken.create!(
      authorization:,
      token_hash: SecureRandom.hex,
      family_id: SecureRandom.uuid,
      scopes: [],
      grant_version: authorization.grant_version,
      expires_at:,
    )
  end

  def expect_delete_batches(queries, table, count)
    delete_queries = queries.grep(/DELETE FROM "#{table}"/)
    expect(delete_queries.size).to eq(count), -> { delete_queries.join("\n") }
  end
end

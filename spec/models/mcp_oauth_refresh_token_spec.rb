# frozen_string_literal: true

describe McpOauthRefreshToken do
  fab!(:user)

  it "keeps the original family expiry when rotating a token" do
    client =
      McpOauthClient.create!(
        client_id: "refresh-token-spec-client",
        name: "Refresh token spec client",
        registration_type: "pre_registered",
        trust_state: "approved",
        redirect_uris: ["http://127.0.0.1/callback"],
      )
    authorization =
      McpOauthAuthorization.create!(
        user:,
        client:,
        resource: DiscourseMcp.resource_url,
        consented_at: Time.zone.now,
        status: "active",
      )
    _, parent = described_class.issue!(authorization:)
    parent.update!(expires_at: 1.day.from_now)

    _, replacement =
      described_class.issue!(authorization:, family_id: parent.family_id, parent: parent)

    expect(replacement.expires_at).to eq_time(parent.expires_at)
  end
end

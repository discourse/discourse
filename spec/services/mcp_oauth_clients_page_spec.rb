# frozen_string_literal: true

describe McpOauthClientsPage do
  fab!(:user)
  fab!(:other_user, :user)

  it "returns authorization counts without loading authorization records" do
    client =
      McpOauthClient.create!(
        client_id: "counted-client",
        name: "Counted client",
        registration_type: "pre_registered",
        trust_state: "approved",
        redirect_uris: ["https://client.example.com/callback"],
      )
    [user, other_user].each do |authorization_user|
      McpOauthAuthorization.create!(
        user: authorization_user,
        client:,
        resource: DiscourseMcp.resource_url,
        status: "active",
        consented_at: Time.current,
      )
    end

    record = described_class.new(limit: 50).call.records.first

    expect(record.authorization_count).to eq(2)
    expect(record.association(:authorizations)).not_to be_loaded
  end
end

# frozen_string_literal: true

describe McpOauthClientIdMetadataPolicy do
  it "returns translated policy values" do
    expect(described_class.values).to contain_exactly(
      { name: "mcp_oauth_client_id_metadata_policy.disabled", value: "disabled" },
      { name: "mcp_oauth_client_id_metadata_policy.approved_domains", value: "approved_domains" },
      { name: "mcp_oauth_client_id_metadata_policy.any_domain", value: "any_domain" },
    )
    expect(described_class.translate_names?).to eq(true)
  end

  it "validates policy values" do
    expect(described_class.valid_value?("disabled")).to eq(true)
    expect(described_class.valid_value?("approved_domains")).to eq(true)
    expect(described_class.valid_value?("any_domain")).to eq(true)
    expect(described_class.valid_value?("invalid")).to eq(false)
  end
end

# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::CredentialSerializer do
  describe "#as_json" do
    it "hides all stored data when the credential type is no longer registered" do
      credential =
        Fabricate(
          :discourse_workflows_credential,
          credential_type: "unregistered_provider",
          data: {
            "client_secret" => "private-secret",
            "access_token" => "private-token",
          },
        )

      serialized = described_class.new(credential, root: false).as_json.deep_stringify_keys

      expect(serialized["data"]).to eq({})
      expect(serialized["data_modes"]).to eq({})
      expect(serialized.to_json).not_to include(*credential.data.values)
    end
  end
end

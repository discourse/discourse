# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Registry do
  before { described_class.reset! }

  describe ".register_credential_type" do
    it "registers a credential type class" do
      described_class.register_credential_type(DiscourseWorkflows::CredentialTypes::BasicAuth)
      expect(described_class.credential_types).to include(
        DiscourseWorkflows::CredentialTypes::BasicAuth,
      )
    end
  end

  describe ".find_credential_type" do
    before do
      described_class.register_credential_type(DiscourseWorkflows::CredentialTypes::BasicAuth)
    end

    it "finds a credential type by identifier" do
      result = described_class.find_credential_type("basic_auth")
      expect(result).to eq(DiscourseWorkflows::CredentialTypes::BasicAuth)
    end

    it "returns nil for unknown identifier" do
      expect(described_class.find_credential_type("unknown")).to be_nil
    end
  end
end

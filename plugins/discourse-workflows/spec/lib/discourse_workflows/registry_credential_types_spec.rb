# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Registry do
  before { described_class.reset_indexes! }

  describe ".credential_types" do
    it "returns registered credential types from the plugin registry" do
      expect(described_class.credential_types).to be_present
      expect(described_class.credential_types.all? { |ct| ct.respond_to?(:identifier) }).to be(true)
    end
  end

  describe ".find_credential_type" do
    it "finds a credential type by identifier" do
      result = described_class.find_credential_type("basic_auth")
      expect(result).to eq(DiscourseWorkflows::CredentialTypes::BasicAuth)
    end

    it "returns nil for unknown identifier" do
      expect(described_class.find_credential_type("unknown")).to be_nil
    end
  end
end

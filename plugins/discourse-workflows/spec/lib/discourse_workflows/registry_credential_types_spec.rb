# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Registry do
  before { described_class.reset_indexes! }

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

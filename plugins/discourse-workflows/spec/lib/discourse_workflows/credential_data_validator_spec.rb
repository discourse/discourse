# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::CredentialDataValidator do
  describe ".call" do
    let(:credential_type) { DiscourseWorkflows::CredentialTypes::BasicAuth }

    it "returns no missing fields when all required fields are present" do
      result =
        described_class.call(
          credential_type: credential_type,
          data: {
            "user" => "admin",
            "password" => "secret",
          },
        )

      expect(result).to be_empty
    end

    it "accepts symbol-keyed data" do
      result =
        described_class.call(
          credential_type: credential_type,
          data: {
            user: "admin",
            password: "secret",
          },
        )

      expect(result).to be_empty
    end

    it "returns missing required fields when data is empty" do
      result = described_class.call(credential_type: credential_type, data: {})

      expect(result).to contain_exactly("user", "password")
    end

    it "returns missing required fields when data is nil" do
      result = described_class.call(credential_type: credential_type, data: nil)

      expect(result).to contain_exactly("user", "password")
    end

    it "treats nil values as missing" do
      result =
        described_class.call(
          credential_type: credential_type,
          data: {
            "user" => "admin",
            "password" => nil,
          },
        )

      expect(result).to contain_exactly("password")
    end

    it "treats empty strings as missing" do
      result =
        described_class.call(
          credential_type: credential_type,
          data: {
            "user" => "admin",
            "password" => "",
          },
        )

      expect(result).to contain_exactly("password")
    end

    it "treats whitespace-only strings as missing" do
      result =
        described_class.call(
          credential_type: credential_type,
          data: {
            "user" => "  ",
            "password" => "secret",
          },
        )

      expect(result).to contain_exactly("user")
    end

    it "ignores non-required fields" do
      type_class =
        Class.new do
          def self.property_schema
            { foo: { type: :string, required: true }, bar: { type: :string } }
          end
        end

      result = described_class.call(credential_type: type_class, data: { "foo" => "x" })

      expect(result).to be_empty
    end

    it "returns empty array when schema is empty" do
      type_class = Class.new { def self.property_schema = {} }

      result = described_class.call(credential_type: type_class, data: { "anything" => "x" })

      expect(result).to be_empty
    end

    it "returns empty array when schema is nil" do
      type_class = Class.new { def self.property_schema = nil }

      result = described_class.call(credential_type: type_class, data: {})

      expect(result).to be_empty
    end
  end
end

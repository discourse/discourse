# frozen_string_literal: true

RSpec.describe Categories::Types::Base do
  describe ".type_id" do
    it "can be explicitly set" do
      test_type = Class.new(described_class)
      test_type.type_id(:custom)

      expect(test_type.type_id).to eq(:custom)
    end
  end

  describe ".metadata" do
    it "returns type information including configuration_schema" do
      expect(described_class.metadata).to include(
        id: :base,
        icon: "comments",
        available: true,
        configuration_schema: [],
      )
    end
  end

  describe ".configure_site_settings" do
    it "applies site settings from configuration_schema defaults" do
      test_type =
        Class.new(described_class) do
          type_id :test_configure

          def self.configuration_schema
            { site_settings: { title: "Configured Forum" } }
          end
        end

      test_type.configure_site_settings(nil)
      expect(SiteSetting.title).to eq("Configured Forum")
    end

    it "prefers configuration_values over defaults" do
      test_type =
        Class.new(described_class) do
          type_id :test_configure_override

          def self.configuration_schema
            { site_settings: { title: "Default" } }
          end
        end

      test_type.configure_site_settings(nil, configuration_values: { "title" => "Override" })
      expect(SiteSetting.title).to eq("Override")
    end
  end

  describe ".resolved_configuration_schema" do
    it "resolves site setting metadata" do
      test_type =
        Class.new(described_class) do
          type_id :test_site_settings

          def self.configuration_schema
            { site_settings: { title: "My Forum" } }
          end
        end

      schema = test_type.send(:resolved_configuration_schema)
      expect(schema.length).to eq(1)

      entry = schema.first
      expect(entry[:key]).to eq("title")
      expect(entry[:default]).to eq("My Forum")
      expect(entry[:type]).to be_present
      expect(entry[:label]).to be_present
    end

    it "passes through category settings" do
      test_type =
        Class.new(described_class) do
          type_id :test_category_settings

          def self.configuration_schema
            { category_settings: { my_field: { default: 42, type: :integer, label: "My Field" } } }
          end
        end

      schema = test_type.send(:resolved_configuration_schema)
      expect(schema.length).to eq(1)

      entry = schema.first
      expect(entry[:key]).to eq("my_field")
      expect(entry[:default]).to eq(42)
      expect(entry[:type]).to eq("integer")
      expect(entry[:label]).to eq("My Field")
    end
  end
end

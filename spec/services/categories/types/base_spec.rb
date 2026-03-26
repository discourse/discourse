# frozen_string_literal: true

RSpec.describe Categories::Types::Base do
  fab!(:admin)
  fab!(:category)

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
        icon: "memo",
        available: true,
        configuration_schema: {
        },
      )
    end
  end

  describe ".additional_metadata" do
    it "returns an empty hash by default" do
      expect(described_class.additional_metadata).to eq({})
    end

    it "is merged into metadata when overridden by a subclass" do
      test_type =
        Class.new(described_class) do
          type_id :with_extra_metadata

          def self.additional_metadata
            { feature_flags: %w[a b] }
          end
        end

      expect(test_type.metadata).to include(feature_flags: %w[a b])
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

      test_type.configure_site_settings(category, guardian: admin.guardian)
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

      test_type.configure_site_settings(
        category,
        guardian: admin.guardian,
        configuration_values: {
          "title" => "Override",
        },
      )
      expect(SiteSetting.title).to eq("Override")
    end
  end

  describe ".validate_schema!" do
    it "accepts an empty hash" do
      expect { described_class.validate_schema! }.not_to raise_error
    end

    it "accepts a valid schema with site_settings" do
      test_type =
        Class.new(described_class) do
          def self.configuration_schema
            { site_settings: { title: "My Forum" } }
          end
        end
      expect { test_type.validate_schema! }.not_to raise_error
    end

    it "accepts a valid schema with category_custom_fields" do
      test_type =
        Class.new(described_class) do
          def self.configuration_schema
            {
              category_custom_fields: {
                my_field: {
                  default: 42,
                  type: :integer,
                  label: "My Field",
                },
              },
            }
          end
        end
      expect { test_type.validate_schema! }.not_to raise_error
    end

    it "accepts optional :description" do
      test_type =
        Class.new(described_class) do
          def self.configuration_schema
            {
              category_custom_fields: {
                my_field: {
                  default: nil,
                  type: :string,
                  label: "My Field",
                  description: "Details",
                },
              },
            }
          end
        end
      expect { test_type.validate_schema! }.not_to raise_error
    end

    it "accepts empty sub-hashes" do
      test_type =
        Class.new(described_class) do
          def self.configuration_schema
            { category_settings: {} }
          end
        end
      expect { test_type.validate_schema! }.not_to raise_error
    end

    it "raises on unknown top-level keys" do
      test_type =
        Class.new(described_class) do
          def self.configuration_schema
            { unknown_key: {} }
          end
        end
      expect { test_type.validate_schema! }.to raise_error(ArgumentError)
    end

    it "raises when site_settings references an unknown SiteSetting" do
      test_type =
        Class.new(described_class) do
          def self.configuration_schema
            { site_settings: { not_a_real_setting_xyzzy: true } }
          end
        end
      expect { test_type.validate_schema! }.to raise_error(ArgumentError, /unknown SiteSetting/)
    end

    it "raises when a field config is missing :default" do
      test_type =
        Class.new(described_class) do
          def self.configuration_schema
            { category_custom_fields: { my_field: { type: :integer, label: "My Field" } } }
          end
        end
      expect { test_type.validate_schema! }.to raise_error(ArgumentError)
    end

    it "raises when a field config :label is empty" do
      test_type =
        Class.new(described_class) do
          def self.configuration_schema
            { category_custom_fields: { my_field: { default: 1, type: :integer, label: "" } } }
          end
        end
      expect { test_type.validate_schema! }.to raise_error(ArgumentError)
    end
  end

  describe "all registered category types" do
    it "have valid configuration schemas" do
      Categories::TypeRegistry.all.each_value do |type_klass|
        expect { type_klass.validate_schema! }.not_to raise_error
      end
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
      expect(schema.keys).to eq(
        %i[general_category_settings site_settings category_settings category_custom_fields],
      )

      entry = schema[:site_settings].first
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
      expect(schema.keys).to eq(
        %i[general_category_settings site_settings category_settings category_custom_fields],
      )

      entry = schema[:category_settings].first
      expect(entry[:key]).to eq("my_field")
      expect(entry[:default]).to eq(42)
      expect(entry[:type]).to eq("integer")
      expect(entry[:label]).to eq("My Field")
    end

    it "returns a hash (not array) when configuration_schema is empty" do
      schema = described_class.send(:resolved_configuration_schema)
      expect(schema).to be_a(Hash)
    end

    it "uses custom labels from the labels hash when present" do
      test_type =
        Class.new(described_class) do
          type_id :test_labels

          def self.configuration_schema
            { site_settings: { title: "My Forum", labels: { title: "Custom title label" } } }
          end
        end

      schema = test_type.send(:resolved_configuration_schema)
      entry = schema[:site_settings].first
      expect(entry[:label]).to eq("Custom title label")
    end

    it "falls back to humanized_name when no label override exists" do
      test_type =
        Class.new(described_class) do
          type_id :test_no_labels

          def self.configuration_schema
            { site_settings: { title: "My Forum" } }
          end
        end

      schema = test_type.send(:resolved_configuration_schema)
      entry = schema[:site_settings].first
      expect(entry[:label]).to eq(SiteSetting.setting_metadata_hash(:title)[:humanized_name])
    end

    it "includes depends_on when site setting uses hash config" do
      test_type =
        Class.new(described_class) do
          type_id :test_depends_on

          def self.configuration_schema
            {
              site_settings: {
                title: "My Forum",
                site_description: {
                  default: "A great forum",
                  depends_on: :title,
                },
              },
            }
          end
        end

      schema = test_type.send(:resolved_configuration_schema)
      title_entry = schema[:site_settings].find { |e| e[:key] == "title" }
      desc_entry = schema[:site_settings].find { |e| e[:key] == "site_description" }

      expect(title_entry).not_to have_key(:depends_on)
      expect(desc_entry[:depends_on]).to eq("title")
      expect(desc_entry[:default]).to eq("A great forum")
    end
  end

  describe ".configure_site_settings" do
    it "extracts default from hash config values" do
      test_type =
        Class.new(described_class) do
          type_id :test_hash_config

          def self.configuration_schema
            { site_settings: { title: { default: "Hash Default", depends_on: :some_toggle } } }
          end
        end

      test_type.configure_site_settings(category, guardian: admin.guardian)
      expect(SiteSetting.title).to eq("Hash Default")
    end
  end

  describe ".validate_schema!" do
    it "skips the labels key when validating site_settings" do
      test_type =
        Class.new(described_class) do
          def self.configuration_schema
            { site_settings: { title: "My Forum", labels: { title: "Custom label" } } }
          end
        end
      expect { test_type.validate_schema! }.not_to raise_error
    end
  end

  describe "category_type_site_setting_names with empty schema" do
    it "does not raise when a matched type has no configuration_schema" do
      test_type =
        Class.new(described_class) do
          type_id :no_schema_test
          def self.category_matches?(_category)
            true
          end
        end

      Categories::TypeRegistry.register(test_type, plugin_identifier: "test")
      SiteSetting.enable_simplified_category_creation = true

      expect { category.category_type_site_setting_names }.not_to raise_error
    ensure
      Categories::TypeRegistry.all.delete(:no_schema_test)
    end
  end
end

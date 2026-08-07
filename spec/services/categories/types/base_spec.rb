# frozen_string_literal: true

RSpec.describe Categories::Types::Base do
  fab!(:admin)
  fab!(:category)

  def build_test_type(id, **options)
    Class.new(described_class) do
      type_id id

      define_singleton_method(:enable_plugin) {} if options.key?(:enable_plugin)

      if options.key?(:plugin_enabled)
        define_singleton_method(:plugin_enabled?) { options[:plugin_enabled] }
      end

      define_singleton_method(:available?) { options[:available] } if options.key?(:available)

      if options.key?(:category_matches)
        define_singleton_method(:category_matches?) { |_| options[:category_matches] }
      end

      if options.key?(:configuration_schema)
        schema = options[:configuration_schema]
        define_singleton_method(:configuration_schema) { schema }
      end

      if options.key?(:additional_metadata)
        meta = options[:additional_metadata]
        define_singleton_method(:additional_metadata) { meta }
      end
    end
  end

  describe ".type_id" do
    it "can be explicitly set" do
      test_type = Class.new(described_class)
      test_type.type_id(:custom)

      expect(test_type.type_id).to eq(:custom)
    end
  end

  describe ".enables_plugin?" do
    it "returns false when enable_plugin is not overridden" do
      test_type = build_test_type(:no_plugin)

      expect(test_type.enables_plugin?).to eq(false)
    end

    it "returns true when enable_plugin is overridden" do
      test_type = build_test_type(:with_plugin, enable_plugin: true)

      expect(test_type.enables_plugin?).to eq(true)
    end
  end

  describe ".plugin_enabled?" do
    it "returns true when enable_plugin is not overridden" do
      test_type = build_test_type(:no_plugin)

      expect(test_type.plugin_enabled?).to eq(true)
    end

    it "raises NotImplementedError when enable_plugin is overridden but plugin_enabled? is not" do
      test_type = build_test_type(:with_plugin, enable_plugin: true)

      expect { test_type.plugin_enabled? }.to raise_error(NotImplementedError)
    end
  end

  describe ".available_for?" do
    fab!(:moderator)

    it "returns true for types that don't enable plugins regardless of guardian" do
      test_type = build_test_type(:no_plugin_type)

      expect(test_type.available_for?(admin.guardian)).to eq(true)
      expect(test_type.available_for?(moderator.guardian)).to eq(true)
      expect(test_type.available_for?).to eq(true)
    end

    it "returns true for plugin-enabling types when user is admin and plugin is not enabled" do
      test_type = build_test_type(:plugin_type, enable_plugin: true, plugin_enabled: false)

      expect(test_type.available_for?(admin.guardian)).to eq(true)
    end

    it "returns false for plugin-enabling types when user is not admin and plugin is not enabled" do
      test_type = build_test_type(:plugin_type_mod, enable_plugin: true, plugin_enabled: false)

      expect(test_type.available_for?(moderator.guardian)).to eq(false)
    end

    it "returns true for plugin-enabling types when user is not admin but plugin is already enabled" do
      test_type = build_test_type(:plugin_type_enabled, enable_plugin: true, plugin_enabled: true)

      expect(test_type.available_for?(moderator.guardian)).to eq(true)
    end

    it "respects the base available? method" do
      test_type = build_test_type(:unavailable_type, available: false)

      expect(test_type.available_for?(admin.guardian)).to eq(false)
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
        build_test_type(:with_extra_metadata, additional_metadata: { feature_flags: %w[a b] })

      expect(test_type.metadata).to include(feature_flags: %w[a b])
    end
  end

  describe ".configure_site_settings" do
    it "applies site settings from configuration_schema defaults" do
      test_type =
        build_test_type(
          :test_configure,
          configuration_schema: {
            site_settings: {
              title: "Configured Forum",
            },
          },
        )

      test_type.configure_site_settings(category, guardian: admin.guardian)
      expect(SiteSetting.title).to eq("Configured Forum")
    end

    it "prefers configuration_values over defaults" do
      test_type =
        build_test_type(
          :test_configure_override,
          configuration_schema: {
            site_settings: {
              title: "Default",
            },
          },
        )

      test_type.configure_site_settings(
        category,
        guardian: admin.guardian,
        configuration_values: {
          title: "Override",
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
        build_test_type(:test, configuration_schema: { site_settings: { title: "My Forum" } })
      expect { test_type.validate_schema! }.not_to raise_error
    end

    it "accepts a valid schema with category_custom_fields" do
      test_type =
        build_test_type(
          :test,
          configuration_schema: {
            category_custom_fields: {
              my_field: {
                default: 42,
                type: :integer,
                label: "My Field",
              },
            },
          },
        )
      expect { test_type.validate_schema! }.not_to raise_error
    end

    it "accepts optional :description" do
      test_type =
        build_test_type(
          :test,
          configuration_schema: {
            category_custom_fields: {
              my_field: {
                default: nil,
                type: :string,
                label: "My Field",
                description: "Details",
              },
            },
          },
        )
      expect { test_type.validate_schema! }.not_to raise_error
    end

    it "accepts empty sub-hashes" do
      test_type = build_test_type(:test, configuration_schema: { category_settings: {} })
      expect { test_type.validate_schema! }.not_to raise_error
    end

    it "raises on unknown top-level keys" do
      test_type = build_test_type(:test, configuration_schema: { unknown_key: {} })
      expect { test_type.validate_schema! }.to raise_error(ArgumentError)
    end

    it "raises when site_settings references an unknown SiteSetting" do
      test_type =
        build_test_type(
          :test,
          configuration_schema: {
            site_settings: {
              not_a_real_setting_xyzzy: true,
            },
          },
        )
      expect { test_type.validate_schema! }.to raise_error(ArgumentError, /unknown SiteSetting/)
    end

    it "raises when a field config is missing :default" do
      test_type =
        build_test_type(
          :test,
          configuration_schema: {
            category_custom_fields: {
              my_field: {
                type: :integer,
                label: "My Field",
              },
            },
          },
        )
      expect { test_type.validate_schema! }.to raise_error(ArgumentError)
    end

    it "raises when a field config :label is empty" do
      test_type =
        build_test_type(
          :test,
          configuration_schema: {
            category_custom_fields: {
              my_field: {
                default: 1,
                type: :integer,
                label: "",
              },
            },
          },
        )
      expect { test_type.validate_schema! }.to raise_error(ArgumentError)
    end

    it "accepts a category custom field with depends_on" do
      test_type =
        Class.new(described_class) do
          def self.configuration_schema
            {
              category_custom_fields: {
                my_field: {
                  default: false,
                  type: :bool,
                  label: "My Field",
                  depends_on: "other_field",
                },
              },
            }
          end
        end
      expect { test_type.validate_schema! }.not_to raise_error
    end

    it "accepts a valid site_texts field" do
      test_type =
        Class.new(described_class) do
          def self.configuration_schema
            { site_texts: { "js.some.key" => { label: "Some label", depends_on: "other_field" } } }
          end
        end
      expect { test_type.validate_schema! }.not_to raise_error
    end

    it "raises when a site_texts field is missing :label" do
      test_type =
        Class.new(described_class) do
          def self.configuration_schema
            { site_texts: { "js.some.key" => { description: "No label here" } } }
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
        build_test_type(
          :test_site_settings,
          configuration_schema: {
            site_settings: {
              title: "My Forum",
            },
          },
        )

      schema = test_type.send(:resolved_configuration_schema)
      expect(schema.keys).to eq(
        %i[
          general_category_settings
          site_settings
          category_settings
          category_custom_fields
          site_texts
        ],
      )

      entry = schema[:site_settings].first
      expect(entry[:key]).to eq("title")
      expect(entry[:default]).to eq("My Forum")
      expect(entry[:type]).to be_present
      expect(entry[:label]).to be_present
    end

    it "reflects whether the site setting has been overridden" do
      test_type =
        build_test_type(
          :test_overridden,
          configuration_schema: {
            site_settings: {
              title: "My Forum",
            },
          },
        )

      entry = test_type.send(:resolved_configuration_schema)[:site_settings].first
      expect(entry[:overridden]).to eq(false)

      SiteSetting.title = "Customized"

      entry = test_type.send(:resolved_configuration_schema)[:site_settings].first
      expect(entry[:overridden]).to eq(true)
    end

    it "passes through category settings" do
      test_type =
        build_test_type(
          :test_category_settings,
          configuration_schema: {
            category_settings: {
              my_field: {
                default: 42,
                type: :integer,
                label: "My Field",
              },
            },
          },
        )

      schema = test_type.send(:resolved_configuration_schema)
      expect(schema.keys).to eq(
        %i[
          general_category_settings
          site_settings
          category_settings
          category_custom_fields
          site_texts
        ],
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

    it "uses custom label from the hash config when present" do
      test_type =
        build_test_type(
          :test_labels,
          configuration_schema: {
            site_settings: {
              title: {
                default: "My Forum",
                label: "Custom title label",
              },
            },
          },
        )

      schema = test_type.send(:resolved_configuration_schema)
      entry = schema[:site_settings].first
      expect(entry[:label]).to eq("Custom title label")
    end

    it "falls back to humanized_name when no label override exists" do
      test_type =
        build_test_type(
          :test_no_labels,
          configuration_schema: {
            site_settings: {
              title: "My Forum",
            },
          },
        )

      schema = test_type.send(:resolved_configuration_schema)
      entry = schema[:site_settings].first
      expect(entry[:label]).to eq(SiteSetting.setting_metadata_hash(:title)[:humanized_name])
    end

    it "includes min and max when present in site setting metadata" do
      test_type =
        build_test_type(
          :test_min_max,
          configuration_schema: {
            site_settings: {
              suggested_topics_unread_max_days_old: 7,
            },
          },
        )

      schema = test_type.send(:resolved_configuration_schema)
      entry = schema[:site_settings].find { |e| e[:key] == "suggested_topics_unread_max_days_old" }

      expect(entry[:min]).to eq(0)
      expect(entry[:max]).to eq(36_500)
    end

    it "does not include min or max when absent from site setting metadata" do
      test_type =
        build_test_type(
          :test_no_min_max,
          configuration_schema: {
            site_settings: {
              title: "My Forum",
            },
          },
        )

      schema = test_type.send(:resolved_configuration_schema)
      entry = schema[:site_settings].find { |e| e[:key] == "title" }

      expect(entry).not_to have_key(:min)
      expect(entry).not_to have_key(:max)
    end

    it "infers depends_on from site setting metadata" do
      test_type =
        build_test_type(
          :test_depends_on,
          configuration_schema: {
            site_settings: {
              title: "My Forum",
              set_locale_from_accept_language_header: true,
            },
          },
        )

      schema = test_type.send(:resolved_configuration_schema)
      title_entry = schema[:site_settings].find { |e| e[:key] == "title" }
      dependent_entry =
        schema[:site_settings].find { |e| e[:key] == "set_locale_from_accept_language_header" }

      expect(title_entry).not_to have_key(:depends_on)
      expect(dependent_entry[:depends_on]).to eq("allow_user_locale")
    end

    it "resolves depends_on for category custom fields" do
      test_type =
        Class.new(described_class) do
          type_id :test_custom_field_depends_on

          def self.configuration_schema
            {
              category_custom_fields: {
                my_field: {
                  default: false,
                  type: :bool,
                  label: "My Field",
                  depends_on: "other_field",
                },
              },
            }
          end
        end

      schema = test_type.send(:resolved_configuration_schema)
      entry = schema[:category_custom_fields].first
      expect(entry[:depends_on]).to eq("other_field")
    end

    it "resolves site_texts entries with the current translation value" do
      test_type =
        Class.new(described_class) do
          type_id :test_site_texts

          def self.configuration_schema
            { site_texts: { "js.some.key" => { label: "Some label", depends_on: "other_field" } } }
          end
        end

      I18n.backend.store_translations(:en, js: { some: { key: "Hello" } })

      schema = test_type.send(:resolved_configuration_schema)
      entry = schema[:site_texts].first
      expect(entry[:key]).to eq("js.some.key")
      expect(entry[:name]).to eq("js_some_key")
      expect(entry[:label]).to eq("Some label")
      expect(entry[:current]).to eq("Hello")
      expect(entry[:depends_on]).to eq("other_field")
    end
  end

  describe ".configure_site_settings" do
    it "extracts default from hash config values" do
      test_type =
        build_test_type(
          :test_hash_config,
          configuration_schema: {
            site_settings: {
              title: {
                default: "Hash Default",
              },
            },
          },
        )

      test_type.configure_site_settings(category, guardian: admin.guardian)
      expect(SiteSetting.title).to eq("Hash Default")
    end
  end

  describe "category_type_site_setting_names with empty schema" do
    it "does not raise when a matched type has no configuration_schema" do
      test_type = build_test_type(:no_schema_test, category_matches: true)

      Categories::TypeRegistry.register(test_type, plugin_identifier: "test")

      expect { category.category_type_site_setting_names }.not_to raise_error
    ensure
      Categories::TypeRegistry.all.delete(:no_schema_test)
    end
  end

  describe ".most_recently_active_admin" do
    it "returns the most recently active admin" do
      admin.update!(last_seen_at: 1.week.ago)
      admin2 = Fabricate(:admin, last_seen_at: 1.hour.ago)

      expect(described_class.most_recently_active_admin).to eq(admin2)
    end

    it "excludes inactive admins" do
      Fabricate(:admin, last_seen_at: 1.minute.ago, active: false)
      admin.update!(last_seen_at: 1.day.ago)

      expect(described_class.most_recently_active_admin).to eq(admin)
    end
  end

  describe ".metadata contact_admin_username" do
    fab!(:moderator)

    it "includes contact_admin_username when user cannot enable plugin" do
      admin.update!(last_seen_at: 1.minute.ago)
      test_type = build_test_type(:plugin_contact, enable_plugin: true, plugin_enabled: false)
      Categories::TypeRegistry.register(test_type, plugin_identifier: "discourse-test-contact")

      metadata = test_type.metadata(guardian: moderator.guardian)

      expect(metadata[:can_enable_plugin]).to eq(false)
      expect(metadata[:contact_admin_username]).to eq(admin.username)
    ensure
      Categories::TypeRegistry.all.delete(:plugin_contact)
    end

    it "does not include contact_admin_username when user can enable plugin" do
      test_type = build_test_type(:plugin_admin, enable_plugin: true, plugin_enabled: false)
      Categories::TypeRegistry.register(test_type, plugin_identifier: "discourse-test-admin")

      metadata = test_type.metadata(guardian: admin.guardian)

      expect(metadata[:can_enable_plugin]).to eq(true)
      expect(metadata).not_to have_key(:contact_admin_username)
    ensure
      Categories::TypeRegistry.all.delete(:plugin_admin)
    end
  end
end

# frozen_string_literal: true

RSpec.describe Categories::TypeRegistry do
  describe ".all" do
    it "includes the discussion type" do
      expect(described_class.all).to include(discussion: Categories::Types::Discussion)
    end
  end

  describe ".get" do
    it "returns the type class for a valid type" do
      expect(described_class.get(:discussion)).to eq(Categories::Types::Discussion)
    end

    it "returns nil for an unknown type" do
      expect(described_class.get(:unknown)).to be_nil
    end
  end

  describe ".get!" do
    it "raises ArgumentError for an unknown type" do
      expect { described_class.get!(:unknown) }.to raise_error(
        ArgumentError,
        /Unknown category type/,
      )
    end
  end

  describe ".valid?" do
    it "returns true for a valid type" do
      expect(described_class.valid?(:discussion)).to be true
    end

    it "returns false for an unknown type" do
      expect(described_class.valid?(:unknown)).to be false
    end
  end

  describe ".list" do
    it "returns metadata including the discussion type" do
      discussion = described_class.list.find { |t| t[:id] == :discussion }

      expect(discussion).to include(icon: "memo", available: true)
    end

    it "returns only visible types when only_visible is true" do
      Categories::Types::Discussion.stubs(:visible?).returns(false)
      expect(described_class.list(only_visible: true)).to be_empty
    end

    it "passes guardian to metadata when provided" do
      admin = Fabricate(:admin)
      discussion = described_class.list(guardian: admin.guardian).find { |t| t[:id] == :discussion }

      expect(discussion).to include(available: true)
    end

    context "with a plugin-enabling type" do
      let(:test_type) do
        Class.new(Categories::Types::Base) do
          type_id :test_plugin_list_type

          def self.enable_plugin
          end

          def self.plugin_enabled?
            false
          end

          def self.category_matches?(category)
            false
          end

          def self.find_matches
            Category.none
          end

          def self.configure_category(category, guardian:, configuration_values: {})
          end

          def self.unconfigure_category(category, guardian:)
          end
        end
      end

      before do
        plugin = Plugin::Instance.new
        plugin.stubs(:humanized_name).returns("Test")
        Discourse.plugins_by_name["discourse-test-plugin"] = plugin
        described_class.register(test_type, plugin_identifier: "discourse-test-plugin")
      end

      after do
        Discourse.plugins_by_name.delete("discourse-test-plugin")
        described_class.reset!
      end

      it "returns can_enable_plugin: false for moderators" do
        moderator = Fabricate(:moderator)
        type_metadata =
          described_class
            .list(guardian: moderator.guardian)
            .find { |t| t[:id] == :test_plugin_list_type }

        expect(type_metadata[:available]).to eq(true)
        expect(type_metadata[:can_enable_plugin]).to eq(false)
        expect(type_metadata[:required_plugin]).to eq("Test")
      end

      it "returns can_enable_plugin: true for admins" do
        admin = Fabricate(:admin)
        type_metadata =
          described_class
            .list(guardian: admin.guardian)
            .find { |t| t[:id] == :test_plugin_list_type }

        expect(type_metadata[:available]).to eq(true)
        expect(type_metadata[:can_enable_plugin]).to eq(true)
        expect(type_metadata[:required_plugin]).to eq("Test")
      end
    end
  end

  describe ".owner" do
    let(:test_type) { Class.new(Categories::Types::Base).tap { |t| t.type_id(:test_owner_type) } }

    after { described_class.all.delete(:test_owner_type) }

    it "returns nil for types without a plugin identifier" do
      described_class.register(test_type)
      expect(described_class.owner(:test_owner_type)).to be_nil
    end

    it "returns the plugin identifier for registered types" do
      described_class.register(test_type, plugin_identifier: "discourse-test")
      expect(described_class.owner(:test_owner_type)).to eq("discourse-test")
    end
  end

  describe ".plugin_display_name" do
    let(:test_type) do
      Class.new(Categories::Types::Base).tap { |t| t.type_id(:test_display_name_type) }
    end

    after { described_class.all.delete(:test_display_name_type) }

    it "returns nil for types without a plugin identifier" do
      described_class.register(test_type)
      expect(described_class.plugin_display_name(:test_display_name_type)).to be_nil
    end

    it "returns the plugin humanized name" do
      plugin = Plugin::Instance.new
      plugin.stubs(:humanized_name).returns("Solved")
      Discourse.plugins_by_name["discourse-solved-plugin"] = plugin

      described_class.register(test_type, plugin_identifier: "discourse-solved-plugin")
      expect(described_class.plugin_display_name(:test_display_name_type)).to eq("Solved")
    ensure
      Discourse.plugins_by_name.delete("discourse-solved-plugin")
    end
  end

  describe ".counts" do
    it "returns a hash of type_id => count in a single query" do
      counts = nil
      queries = track_sql_queries { counts = described_class.counts }

      expect(counts).to be_a(Hash)
      expect(counts.keys).to include(:discussion)
      expect(counts.values).to all(be_a(Integer))
      expect(queries.size).to eq(1)
    end

    it "returns only the core discussion type in the hash when no other types are registered" do
      original_types = described_class.all.dup
      described_class.reset!
      expect(described_class.counts).to eq({ discussion: 0 })
    ensure
      original_types&.each_value { |klass| described_class.register(klass) }
    end
  end

  describe ".register" do
    let(:test_type) do
      Class.new(Categories::Types::Base).tap { |t| t.type_id(:test_registry_type) }
    end

    after { described_class.all.delete(:test_registry_type) }

    it "registers and exposes a new type" do
      described_class.register(test_type)

      expect(described_class.get(:test_registry_type)).to eq(test_type)
      expect(described_class.valid?(:test_registry_type)).to be true
    end

    it "raises when type_id contains invalid characters" do
      invalid_type = Class.new(Categories::Types::Base).tap { |t| t.type_id(:"invalid-type!") }
      expect { described_class.register(invalid_type) }.to raise_error(
        ArgumentError,
        /must only contain lowercase letters/,
      )
    end

    it "raises when a type_id is already registered by another owner" do
      described_class.register(test_type, plugin_identifier: "plugin-a")

      other_type = Class.new(Categories::Types::Base).tap { |t| t.type_id(:test_registry_type) }

      expect { described_class.register(other_type, plugin_identifier: "plugin-b") }.to raise_error(
        ArgumentError,
        /already registered/,
      )
    end
  end
end

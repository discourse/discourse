# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Schemas::Topic do
  fab!(:post)
  fab!(:topic) { post.topic }
  fab!(:tag)

  before do
    SiteSetting.discourse_workflows_enabled = true
    SiteSetting.tagging_enabled = true
    topic.tags << tag
  end

  describe ".fields" do
    it "returns the base topic fields" do
      expect(described_class.fields).to include(
        id: :integer,
        title: :string,
        raw: :string,
        username: :string,
        tags: :array,
        category_id: :integer,
        status: :string,
      )
    end

    it "includes fields from schema extensions" do
      stub_extension = { name: :topic, fields: { custom_field: :string }, resolver: ->(_) { {} } }

      klass = Class.new(DiscourseWorkflows::NodeType)
      klass.instance_variable_set(:@schema_extensions, [stub_extension])
      allow(klass).to receive(:identifier).and_return("action:test_extension")

      plugin = Plugin::Instance.new
      plugin.enabled_site_setting(:discourse_workflows_enabled)
      DiscoursePluginRegistry.register_discourse_workflows_node(klass, plugin)
      DiscourseWorkflows::Registry.reset_indexes!

      expect(described_class.fields).to include(custom_field: :string)
    ensure
      DiscoursePluginRegistry._raw_discourse_workflows_nodes.reject! { |h| h[:value] == klass }
      DiscourseWorkflows::Registry.reset_indexes!
    end
  end

  describe ".resolve" do
    it "returns all base topic data" do
      data = described_class.resolve(topic)

      expect(data[:id]).to eq(topic.id)
      expect(data[:title]).to eq(topic.title)
      expect(data[:raw]).to eq(post.raw)
      expect(data[:username]).to eq(post.user.username)
      expect(data[:tags]).to contain_exactly(tag.name)
      expect(data[:category_id]).to eq(topic.category_id)
      expect(data[:status]).to eq("open")
    end

    it "merges data from schema extensions" do
      stub_extension = {
        name: :topic,
        fields: {
          custom_field: :string,
        },
        resolver: ->(_topic) { { custom_field: "extended_value" } },
      }

      klass = Class.new(DiscourseWorkflows::NodeType)
      klass.instance_variable_set(:@schema_extensions, [stub_extension])
      allow(klass).to receive(:identifier).and_return("action:test_extension")

      plugin = Plugin::Instance.new
      plugin.enabled_site_setting(:discourse_workflows_enabled)
      DiscoursePluginRegistry.register_discourse_workflows_node(klass, plugin)
      DiscourseWorkflows::Registry.reset_indexes!

      data = described_class.resolve(topic)
      expect(data[:custom_field]).to eq("extended_value")
    ensure
      DiscoursePluginRegistry._raw_discourse_workflows_nodes.reject! { |h| h[:value] == klass }
      DiscourseWorkflows::Registry.reset_indexes!
    end
  end
end

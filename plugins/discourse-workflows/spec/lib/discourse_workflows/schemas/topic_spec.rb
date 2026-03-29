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
        topic_id: :integer,
        topic_title: :string,
        topic_raw: :string,
        username: :string,
        tags: :array,
        category_id: :integer,
        status: :string,
      )
    end

    it "includes fields from schema extensions" do
      stub_extension = { name: :topic, fields: { custom_field: :string }, resolver: ->(_) { {} } }

      klass = Class.new(DiscourseWorkflows::Actions::Base)
      klass.instance_variable_set(:@schema_extensions, [stub_extension])

      DiscourseWorkflows::Registry.register_action(klass, version: "test")
      allow(klass).to receive(:identifier).and_return("action:test_extension")

      expect(described_class.fields).to include(custom_field: :string)
    ensure
      DiscourseWorkflows::Registry.reset!
    end
  end

  describe ".resolve" do
    it "returns all base topic data" do
      data = described_class.resolve(topic)

      expect(data[:topic_id]).to eq(topic.id)
      expect(data[:topic_title]).to eq(topic.title)
      expect(data[:topic_raw]).to eq(post.raw)
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

      klass = Class.new(DiscourseWorkflows::Actions::Base)
      klass.instance_variable_set(:@schema_extensions, [stub_extension])

      DiscourseWorkflows::Registry.register_action(klass, version: "test")
      allow(klass).to receive(:identifier).and_return("action:test_extension")

      data = described_class.resolve(topic)
      expect(data[:custom_field]).to eq("extended_value")
    ensure
      DiscourseWorkflows::Registry.reset!
    end
  end
end

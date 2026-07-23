# frozen_string_literal: true

RSpec.describe DiscourseDataExplorer::JsonApiKit::ResourceBase do
  subject(:resource_class) do
    owner = owner_resource
    tag = tag_resource
    Class.new(described_class) do
      type :things
      description "A thing under test."

      attribute :name, :string, writable: true, example: "Widget"
      attribute :label, :string, description: "Uppercased name." do |thing|
        thing.name.upcase
      end

      has_one :owner, resource: owner
      has_many :tags, resource: tag

      filter(:search, :string, description: "Matches the name.") { |scope, _value| scope }
      sort :name
      sort :renamed, column: :original, nulls: :last
      sort(:popularity) { |scope, _direction| scope }
      default_sort name: :asc
      includes :owner
      stat :total, :count
      page max: 50, default: 10
      base_scope { :the_scope }
    end
  end

  let(:owner_resource) do
    Class.new(described_class) do
      type :owners
      attribute :handle, :string
    end
  end
  let(:tag_resource) do
    Class.new(described_class) do
      type :tags
      attribute :label, :string
    end
  end
  let(:record) { Data.define(:id, :name).new(id: 1, name: "thing") }

  describe ".attribute" do
    it "records the declared type" do
      expect(resource_class.attribute_definitions[:name][:type]).to eq(:string)
    end

    it "defaults to not writable" do
      expect(resource_class.attribute_definitions[:label][:writable]).to be(false)
    end

    it "records writability" do
      expect(resource_class.attribute_definitions[:name][:writable]).to be(true)
    end

    it "records the description" do
      expect(resource_class.attribute_definitions[:label][:description]).to eq("Uppercased name.")
    end

    it "exposes the writable attribute names" do
      expect(resource_class.writable_attribute_names).to eq([:name])
    end

    it "records the example" do
      expect(resource_class.attribute_definitions[:name][:example]).to eq("Widget")
    end

    it "rejects an unknown type at declaration" do
      expect {
        Class.new(described_class) do
          type :broken
          attribute :field, :nonsense
        end
      }.to raise_error(ArgumentError, /nonsense/)
    end
  end

  describe ".description" do
    it "records the resource description" do
      expect(resource_class.description).to eq("A thing under test.")
    end
  end

  describe "rendering" do
    it "serializes declared attributes through the underlying serializer" do
      expect(resource_class.new(record).serializable_hash.dig(:data, :attributes)).to eq(
        name: "thing",
        label: "THING",
      )
    end

    it "stamps the declared type" do
      expect(resource_class.new(record).serializable_hash.dig(:data, :type)).to eq(:things)
    end
  end

  describe ".has_one" do
    it "records a to-one relationship" do
      expect(resource_class.relationship_definitions[:owner]).to eq(
        kind: :has_one,
        resource: owner_resource,
        description: nil,
      )
    end
  end

  describe ".has_many" do
    it "records a to-many relationship" do
      expect(resource_class.relationship_definitions[:tags]).to eq(
        kind: :has_many,
        resource: tag_resource,
        description: nil,
      )
    end
  end

  describe ".filter" do
    it "records the filter's value type" do
      expect(resource_class.filter_definitions[:search][:type]).to eq(:string)
    end

    it "records the description" do
      expect(resource_class.filter_definitions[:search][:description]).to eq("Matches the name.")
    end
  end

  describe "inheritance" do
    subject(:child_class) do
      Class.new(parent_class) do
        type :children
        attribute :label, :string
      end
    end

    let(:parent_class) do
      Class.new(described_class) do
        attribute :created_at, :datetime
        page max: 25, default: 5
      end
    end

    it "inherits the parent's attribute definitions" do
      expect(child_class.attribute_definitions.keys).to eq(%i[created_at label])
    end

    it "inherits the parent's page sizes" do
      expect(child_class.jsonapi_config.max_page_size).to eq(25)
    end

    it "renders the parent's attributes" do
      record = Data.define(:id, :created_at, :label).new(id: 1, created_at: "now", label: "x")
      expect(child_class.new(record).serializable_hash.dig(:data, :attributes)).to eq(
        created_at: "now",
        label: "x",
      )
    end

    it "keeps the child's declarations off the parent" do
      child_class
      expect(parent_class.attribute_definitions.keys).to eq(%i[created_at])
    end
  end

  describe "#jsonapi_config" do
    subject(:config) { resource_class.jsonapi_config }

    it "renders through the resource class itself" do
      expect(config.serializer_class).to be(resource_class)
    end

    it "exposes the filters by name" do
      expect(config.filters.keys).to eq(%w[search])
    end

    it "exposes the sorts with their column mapping" do
      expect(config.sorts["renamed"]).to include(column: :original, nulls: :last)
    end

    it "pins block-backed sorts as virtual" do
      expect(config.virtual_sort_keys).to eq(%w[popularity])
    end

    it "pins filters as virtual" do
      expect(config.virtual_filter_keys).to eq(%w[search])
    end

    it "exposes the default sort" do
      expect(config.default_sort_value).to eq(name: :asc)
    end

    it "exposes the allowed includes" do
      expect(config.allowed_includes).to eq(%w[owner])
    end

    it "exposes the stats" do
      expect(config.stats).to eq("total" => :count)
    end

    it "exposes the page sizes" do
      expect(config.max_page_size).to eq(50)
    end

    it "exposes the base scope block" do
      expect(config.base_scope_block.call).to eq(:the_scope)
    end
  end
end

# frozen_string_literal: true

RSpec.describe JsonApiKit::Declarations::Fields do
  subject(:fields) { described_class.for(names, guardian:, attributes:, relationships:, schema:) }

  let(:guardian) { Guardian.new }

  fab!(:topic) { Fabricate(:topic, title: "A record read as its fields", closed: false) }

  let(:schema) { JsonApiKit::Schema.new(Topic) }
  let(:users_resource) { Class.new(JsonApiKit::Resource) { type :users } }
  let(:attributes) do
    [
      JsonApiKit::Declarations::Attribute.new(:title),
      JsonApiKit::Declarations::Attribute.new(:closed),
    ]
  end
  let(:relationships) do
    [JsonApiKit::Declarations::Relationship::ToOne.new(:user, resource: users_resource)]
  end
  let(:names) { nil }

  describe ".for" do
    context "when an attribute and a relationship share a name" do
      let(:relationships) do
        [JsonApiKit::Declarations::Relationship::ToOne.new(:title, resource: users_resource)]
      end

      it "refuses the declaration" do
        expect { fields }.to raise_error(described_class::Collision, /title/)
      end
    end

    context "when two attributes share a name" do
      let(:attributes) do
        [
          JsonApiKit::Declarations::Attribute.new(:title),
          JsonApiKit::Declarations::Attribute.new(:title),
        ]
      end

      it "refuses the declaration" do
        expect { fields }.to raise_error(described_class::Collision, /title/)
      end
    end

    context "when a field takes a name the kit reserves" do
      let(:attributes) do
        [
          JsonApiKit::Declarations::Attribute.new(:id),
          JsonApiKit::Declarations::Attribute.new(:type),
        ]
      end

      it "refuses the declaration" do
        expect { fields }.to raise_error(described_class::Collision, /id, type/)
      end
    end
  end

  describe "#attributes" do
    subject(:attribute_values) { fields.attributes.values_for(topic) }

    it "holds every field the resource declares" do
      expect(attribute_values.keys).to eq(%w[title closed])
    end

    context "when the fieldset holds one field" do
      let(:names) { %w[title] }

      it "holds only those" do
        expect(attribute_values.keys).to eq(%w[title])
      end
    end

    context "when the fieldset is in another order" do
      let(:names) { %w[closed title] }

      it "holds them in the order the resource declares" do
        expect(attribute_values.keys).to eq(%w[title closed])
      end
    end

    context "when the fieldset holds an unknown field" do
      let(:names) { %w[title secrets] }

      it "leaves that name out" do
        expect(attribute_values.keys).to eq(%w[title])
      end
    end

    context "when the fieldset is empty" do
      let(:names) { [] }

      it "holds no field" do
        expect(attribute_values).to be_empty
      end
    end
  end

  describe "#relationships" do
    subject(:user_relationships) { fields.relationships.pick(%w[user]) }

    it "holds every relationship the resource declares" do
      expect(user_relationships.map(&:name)).to eq(%w[user])
    end

    context "when the fieldset holds an attribute only" do
      let(:names) { %w[title] }

      it "holds no relationship" do
        expect(user_relationships).to be_empty
      end
    end

    context "when the fieldset holds a relationship too" do
      let(:names) { %w[title user] }

      it "holds that relationship" do
        expect(user_relationships.map(&:name)).to eq(%w[user])
      end
    end
  end

  describe "#columns" do
    subject(:columns) { fields.columns }

    it "returns every column" do
      expect(columns).to eq(JsonApiKit::Columns.all)
    end

    context "when the fieldset holds one field" do
      let(:names) { %w[title] }

      it "returns the column of each one" do
        expect(columns).to eq(JsonApiKit::Columns.for(%i[title]))
      end
    end

    context "when the fieldset is empty" do
      let(:names) { [] }

      it "returns no column" do
        expect(columns).to eq(JsonApiKit::Columns.for([]))
      end
    end
  end
end

# frozen_string_literal: true

RSpec.describe JsonApiKit::Declarations::Attributes do
  subject(:attributes) { described_class.new(declarations, guardian:, schema:, type: "topics") }

  fab!(:topic) { Fabricate(:topic, title: "A field rendered from a record", closed: false) }

  let(:guardian) { Guardian.new }
  let(:schema) { JsonApiKit::Schema.new(Topic) }
  let(:attribute) { JsonApiKit::Declarations::Attribute }
  let(:declarations) { [attribute.new(:title), attribute.new(:closed)] }
  let(:title) { JsonApiKit::Name::Field.new(value: "title", type: "topics") }
  let(:closed) { JsonApiKit::Name::Field.new(value: "closed", type: "topics") }

  describe "#columns" do
    subject(:columns) { attributes.columns }

    it "returns the column of every field it holds" do
      expect(columns).to eq(JsonApiKit::Columns.for(%i[title closed]))
    end

    context "when a field declares a value of its own" do
      let(:declarations) { [attribute.new(:title), attribute.new(:slug) { |record| record.title }] }

      it "returns every column" do
        expect(columns).to eq(JsonApiKit::Columns.all)
      end
    end
  end

  describe "#values_for" do
    subject(:attribute_values) { attributes.values_for(topic) }

    it "returns the value of every field it holds, under its name" do
      expect(attribute_values).to eq(title => topic.title, closed => false)
    end

    context "with a second record" do
      fab!(:other_topic) { Fabricate(:topic, title: "Another field rendered from a record") }

      it "builds the name of a field once" do
        expect(attribute_values.keys.first).to equal(attributes.values_for(other_topic).keys.first)
      end
    end

    context "when it holds no field" do
      let(:declarations) { [] }

      it "returns no value" do
        expect(attribute_values).to be_empty
      end
    end
  end
end

# frozen_string_literal: true

RSpec.describe JsonApiKit::Declarations::Attribute do
  subject(:attribute) { described_class.new(:title) }

  fab!(:topic) { Fabricate(:topic, title: "A field rendered from a record") }

  describe "#name" do
    subject(:name) { attribute.name }

    it "returns the name the field goes out under" do
      expect(name).to eq("title")
    end
  end

  describe "#value_for" do
    subject(:value) { attribute.value_for(topic) }

    it "returns what the record holds under that name" do
      expect(value).to eq(topic.title)
    end

    context "when the attribute declares a value of its own" do
      subject(:attribute) { described_class.new(:slug) { |record| record.title.parameterize } }

      it "returns what that declaration makes of the record" do
        expect(value).to eq("a-field-rendered-from-a-record")
      end
    end
  end

  describe "#column_for" do
    subject(:column) { attribute.column_for(JsonApiKit::Schema.new(Topic)) }

    it "returns the column the field reads" do
      expect(column).to eq(:title)
    end

    context "when the attribute declares a value of its own" do
      subject(:attribute) { described_class.new(:slug) { |record| record.title.parameterize } }

      it "returns no column" do
        expect(column).to be_nil
      end
    end
  end
end

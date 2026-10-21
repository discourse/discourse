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

  describe "#columns_for" do
    subject(:columns) { attribute.columns_for(JsonApiKit::Schema.new(Topic)) }

    it "returns the column the field reads" do
      expect(columns).to eq([:title])
    end

    context "when the attribute declares a value of its own" do
      subject(:attribute) { described_class.new(:slug) { |record| record.title.parameterize } }

      it "returns a column it can't name" do
        expect(columns).to eq([nil])
      end
    end

    context "when the attribute names the columns its value reads" do
      subject(:attribute) do
        described_class.new(:slug, columns: %i[title closed]) { |record| record.title.parameterize }
      end

      it "returns those columns" do
        expect(columns).to eq(%i[title closed])
      end
    end
  end
end

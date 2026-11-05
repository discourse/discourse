# frozen_string_literal: true

RSpec.describe JsonApiKit::Declarations::Attribute do
  subject(:attribute) { described_class.new(:title) }

  fab!(:topic) { Fabricate(:topic, title: "A field rendered from a record") }

  describe ".new" do
    subject(:attribute) { described_class.new(:title, type, **options) }

    let(:type) { :string }
    let(:options) { { writable: true } }

    context "when a writable attribute has no type" do
      let(:type) { nil }

      it "requires a type" do
        expect { attribute }.to raise_error(ArgumentError, /title.*type/)
      end
    end

    context "when the type is unknown" do
      let(:type) { :unknown }

      it "refuses the declaration" do
        expect { attribute }.to raise_error(ArgumentError, /Unknown type/)
      end
    end

    context "when writability is not a boolean" do
      let(:options) { super().merge(writable: "false") }

      it "requires a boolean" do
        expect { attribute }.to raise_error(ArgumentError, /writable.*true or false/)
      end
    end
  end

  describe "#type" do
    subject(:type) { attribute.type }

    it "leaves the type unspecified" do
      expect(type).to be_nil
    end
  end

  describe "#writable?" do
    it "defaults to read-only" do
      expect(attribute).not_to be_writable
    end
  end

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
end

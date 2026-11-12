# frozen_string_literal: true

RSpec.describe JsonApiKit::Declarations::Filter do
  subject(:filter) { described_class.new(:title) { |titles, value| titles.reject { it == value } } }

  describe "#name" do
    subject(:name) { filter.name }

    it "returns the filter name" do
      expect(name).to eq("title")
    end
  end

  describe "#apply" do
    subject(:filtered_titles) { filter.apply(scope, value, adapter:) }

    let(:scope) { [value, other_title] }
    let(:value) { "First topic" }
    let(:other_title) { "Second topic" }
    let(:adapter) { instance_double(JsonApiKit::Adapters::ActiveRecord) }

    before { allow(adapter).to receive(:filter).with(scope, "title", value).and_return([value]) }

    it "applies the declared condition" do
      expect(filtered_titles).to contain_exactly(other_title)
    end

    context "when the filter declares no condition of its own" do
      let(:filter) { described_class.new(:title) }

      it "returns the adapter's matching rows" do
        expect(filtered_titles).to contain_exactly(value)
      end
    end
  end
end

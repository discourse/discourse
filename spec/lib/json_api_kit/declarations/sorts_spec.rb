# frozen_string_literal: true

RSpec.describe JsonApiKit::Declarations::Sorts do
  subject(:sorts) { described_class.new(declarations) }

  let(:sort_class) { JsonApiKit::Declarations::Sort }
  let(:declarations) do
    [sort_class.new(:created_at), sort_class.new(:ran_at, column: :last_posted_at)]
  end

  describe "#fetch" do
    subject(:sort) { sorts.fetch("created_at") }

    it "returns that sort" do
      expect(sort.name).to eq("created_at")
    end

    context "when the resource declares no sort by that name" do
      subject(:sort) { sorts.fetch("secrets") }

      it "refuses the request" do
        expect { sort }.to raise_error(KeyError)
      end
    end
  end

  describe "#with" do
    subject(:combined) { sorts.with([sort_class.new(:title)]) }

    it "combines current and additional declarations" do
      expect(combined.names).to contain_exactly("created_at", "ran_at", "title")
    end

    it "preserves the original collection" do
      expect { combined.names }.not_to change(sorts, :names)
    end
  end
end

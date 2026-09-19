# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Limit::V1 do
  subject(:result) do
    execute_node_output(configuration: configuration, input_items: input_items).first
  end

  let(:item_count) { 5 }
  let(:input_items) { Array.new(item_count) { |index| { "json" => { "index" => index } } } }
  let(:max_items) { 10 }
  let(:keep) { "first" }
  let(:configuration) { { "max_items" => max_items, "keep" => keep } }

  describe "#execute" do
    context "when keeping the first three items" do
      let(:max_items) { 3 }

      it "returns the first three items" do
        expect(result.map { |item| item["json"]["index"] }).to eq([0, 1, 2])
      end
    end

    context "when keeping the last two items" do
      let(:max_items) { 2 }
      let(:keep) { "last" }

      it "returns the last two items" do
        expect(result.map { |item| item["json"]["index"] }).to eq([3, 4])
      end
    end

    context "when the limit exceeds the input size" do
      let(:item_count) { 3 }

      it "returns all items" do
        expect(result.length).to eq(3)
      end
    end

    context "without input items" do
      let(:input_items) { [] }
      let(:max_items) { 5 }

      it { is_expected.to eq([]) }
    end

    context "without an explicit limit" do
      let(:item_count) { 15 }
      let(:configuration) { {} }

      it "defaults to ten items" do
        expect(result.length).to eq(10)
      end
    end

    context "with a limit of one" do
      let(:max_items) { 1 }

      it "returns the first item" do
        expect(result.map { |item| item["json"]["index"] }).to eq([0])
      end
    end

    context "with a limit below one" do
      let(:max_items) { 0 }

      it "clamps the limit to one" do
        expect(result.map { |item| item["json"]["index"] }).to eq([0])
      end
    end

    context "when keeping the last item" do
      let(:max_items) { 1 }
      let(:keep) { "last" }

      it "returns the last item" do
        expect(result.map { |item| item["json"]["index"] }).to eq([4])
      end
    end

    context "with an expression limit" do
      let(:max_items) { "={{ $json.limit }}" }
      let(:input_items) do
        [{ "json" => { "index" => 0, "limit" => 2 } }] +
          (1...item_count).map { |index| { "json" => { "index" => index } } }
      end

      it "resolves the expression through the execution context" do
        expect(result.map { |item| item["json"]["index"] }).to eq([0, 1])
      end
    end
  end
end

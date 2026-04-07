# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor::ExecutionQueue do
  let(:queue) { described_class.new }

  describe "#enqueue and #shift" do
    it "follows FIFO order" do
      node_a = OpenStruct.new(id: "a")
      node_b = OpenStruct.new(id: "b")
      items_a = [{ "json" => { "a" => 1 } }]
      items_b = [{ "json" => { "b" => 2 } }]

      queue.enqueue(node_a, items_a)
      queue.enqueue(node_b, items_b)

      first_node, first_items = queue.shift
      expect(first_node).to eq(node_a)
      expect(first_items).to eq(items_a)

      second_node, second_items = queue.shift
      expect(second_node).to eq(node_b)
      expect(second_items).to eq(items_b)
    end
  end

  describe "#any?" do
    it "returns false when empty" do
      expect(queue.any?).to be(false)
    end

    it "returns true when items are enqueued" do
      queue.enqueue(OpenStruct.new(id: "a"), [])
      expect(queue.any?).to be(true)
    end

    it "returns false after all items are shifted" do
      queue.enqueue(OpenStruct.new(id: "a"), [])
      queue.shift
      expect(queue.any?).to be(false)
    end
  end

  describe "#clear" do
    it "removes all items" do
      queue.enqueue(OpenStruct.new(id: "a"), [])
      queue.enqueue(OpenStruct.new(id: "b"), [])
      queue.clear
      expect(queue.any?).to be(false)
    end
  end
end

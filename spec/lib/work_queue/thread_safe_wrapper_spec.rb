# frozen_string_literal: true

RSpec.describe WorkQueue::ThreadSafeWrapper do
  subject(:queue) { WorkQueue::ThreadSafeWrapper.new(WorkQueue::BoundedQueue.new(3)) }

  let(:task) { "task1" }

  describe "#push" do
    it "delegates the push operation to the inner queue" do
      queue.push(task, force: false)
      expect(queue).not_to be_empty
    end
  end

  describe "#shift" do
    context "when block is true" do
      it "waits until an item is available and then returns it" do
        result = nil
        thread = Thread.new { result = queue.shift(block: true) }
        expect(thread).to be_alive
        queue.push(task, force: false)
        thread.join
        expect(result).to eq(task)
      end
    end

    context "when block is false" do
      it "returns nil immediately if no item is available" do
        expect(queue.shift(block: false)).to be_nil
      end

      it "returns the first available item if one is present" do
        queue.push(task, force: false)
        expect(queue.shift(block: false)).to eq(task)
      end
    end
  end
end

# frozen_string_literal: true

RSpec.describe WorkQueue::BoundedQueue do
  subject(:queue) { WorkQueue::BoundedQueue.new(3) }

  let(:task1) { "Task 1" }
  let(:task2) { "Task 2" }
  let(:task3) { "Task 3" }
  let(:task4) { "Task 4" }

  describe "#push" do
    context "when the queue is not full" do
      it "adds the task to the queue" do
        queue.push(task1, force: false)
        expect(queue.size).to eq(1)
      end
    end

    context "when the queue is full" do
      before do
        queue.push(task1, force: false)
        queue.push(task2, force: false)
        queue.push(task3, force: false)
      end

      it "adds the task to the queue if force parameter is true" do
        expect { queue.push(task4, force: true) }.not_to raise_error
        expect(queue.size).to eq(4)
      end

      it "raises an error if the force parameter is false" do
        expect { queue.push(task4, force: false) }.to raise_error(WorkQueue::WorkQueueFull)
      end
    end
  end

  describe "#shift" do
    it "removes and returns the first task from the queue" do
      queue.push(task1, force: false)
      queue.push(task2, force: false)

      expect(queue.shift).to eq(task1)
      expect(queue.shift).to eq(task2)

      expect(queue.size).to eq(0)
      expect(queue).to be_empty
    end

    it "returns nil when the queue is empty" do
      shifted_task = queue.shift
      expect(shifted_task).to be_nil
    end
  end

  describe "#empty?" do
    it "returns true if the queue is empty" do
      expect(queue).to be_empty
    end

    it "returns false if the queue is not empty" do
      queue.push(task1, force: false)
      expect(queue).not_to be_empty
    end
  end

  describe "#size" do
    it "returns the number of tasks in the queue" do
      queue.push(task1, force: false)
      queue.push(task2, force: false)
      expect(queue.size).to eq(2)
    end
  end
end

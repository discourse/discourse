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

RSpec.describe WorkQueue::FairQueue do
  subject(:queue) do
    WorkQueue::FairQueue.new(:key, global_limit) { WorkQueue::BoundedQueue.new(per_key_limit) }
  end

  let(:global_limit) { 5 }
  let(:per_key_limit) { 3 }
  let(:key1) { :key1 }
  let(:key2) { :key2 }
  let(:key3) { :key3 }
  let(:task1) { "task1" }
  let(:task2) { "task2" }
  let(:task3) { "task3" }
  let(:task4) { "task4" }
  let(:task5) { "task5" }
  let(:task6) { "task6" }

  describe "#push" do
    context "when no previous tasks exist for the key" do
      it "adds the task to the queue" do
        queue.push({ key: key1, task: task1 }, force: false)
        expect(queue.size).to eq(1)
      end
    end

    context "when the global limit is reached" do
      before do
        queue.push({ key: key1, task: task1 }, force: false)
        queue.push({ key: key2, task: task2 }, force: false)
        queue.push({ key: key3, task: task3 }, force: false)
        queue.push({ key: key1, task: task4 }, force: false)
        queue.push({ key: key2, task: task5 }, force: false)
      end

      it "raises an error if the force parameter is false" do
        expect { queue.push({ key: key3, task: task6 }, force: false) }.to raise_error(
          WorkQueue::WorkQueueFull,
        )
      end

      it "adds the task to the queue if the force parameter is true" do
        queue.push({ key: key3, task: task6 }, force: true)
        expect(queue.size).to eq(6)
      end
    end
  end

  describe "#shift" do
    it "removes and returns tasks in FIFO order when the keys are different" do
      queue.push({ key: key1, task: task1 }, force: false)
      queue.push({ key: key2, task: task2 }, force: false)
      queue.push({ key: key3, task: task3 }, force: false)

      expect(queue.shift).to eq({ key: key1, task: task1 })
      expect(queue.shift).to eq({ key: key2, task: task2 })
      expect(queue.shift).to eq({ key: key3, task: task3 })

      expect(queue.size).to eq(0)
      expect(queue).to be_empty
    end

    it "removes and returns tasks in FIFO order by key when the keys are the same" do
      queue.push({ key: key1, task: task1 }, force: false)
      queue.push({ key: key1, task: task3 }, force: false)
      queue.push({ key: key2, task: task2 }, force: false)
      queue.push({ key: key2, task: task4 }, force: false)

      expect(queue.shift).to eq({ key: key1, task: task1 })
      expect(queue.shift).to eq({ key: key2, task: task2 })
      expect(queue.shift).to eq({ key: key1, task: task3 })
      expect(queue.shift).to eq({ key: key2, task: task4 })

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
      queue.push({ key: key1, task: task1 }, force: false)
      expect(queue).not_to be_empty
    end
  end

  describe "#size" do
    it "returns the number of tasks in the queue" do
      queue.push({ key: key1, task: task1 }, force: false)
      queue.push({ key: key2, task: task2 }, force: false)
      expect(queue.size).to eq(2)
    end
  end
end

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
        shifted_task = queue.shift(block: false)
        expect(shifted_task).to be_nil
      end

      it "returns the first available item if one is present" do
        queue.push(task, force: false)
        shifted_task = queue.shift(block: false)
        expect(shifted_task).to eq(task)
      end
    end
  end
end

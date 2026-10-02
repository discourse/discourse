# frozen_string_literal: true

RSpec.describe Migrations::Importer::Uploads::WorkerGate do
  # A worker thread that acquires a permit, pushes itself onto `admitted`, then
  # waits until the test releases it. Blocking pops act as latches, so the test
  # knows exactly which worker got in and can release that one specifically.
  let(:acquirer_class) do
    Struct.new(:thread, :hold) do
      def release_and_join
        hold << :go
        thread.join
      end
    end
  end

  def acquirer(gate, admitted)
    hold = Queue.new
    worker = acquirer_class.new(nil, hold)
    worker.thread =
      Thread.new do
        Thread.current.report_on_exception = false
        gate.acquire
        admitted << worker
        hold.pop
        gate.release
      end
    worker
  end

  describe "clamping" do
    it "keeps the target within [min, max]" do
      gate = described_class.new(target: 10, max: 4)
      expect(gate.target).to eq(4)

      gate.target = 0
      expect(gate.target).to eq(1) # min defaults to 1

      gate.target = 100
      expect(gate.target).to eq(4)
    end
  end

  describe "#acquire / #release" do
    it "admits up to the target and blocks the rest until a permit frees up" do
      gate = described_class.new(target: 2, max: 4)
      admitted = Queue.new
      workers = Array.new(3) { acquirer(gate, admitted) }

      first = admitted.pop
      second = admitted.pop
      wait_until { gate.waiting == 1 }
      expect(gate.active).to eq(2)
      expect(admitted.size).to eq(0)

      first.release_and_join # frees a permit; the blocked one wakes
      third = admitted.pop
      expect(workers).to contain_exactly(first, second, third)
      expect(gate.active).to eq(2)
      expect(gate.waiting).to eq(0)

      [second, third].each(&:release_and_join)
      expect(gate.active).to eq(0)
    end
  end

  describe "growing the target" do
    it "wakes waiting workers so they take the new slots" do
      gate = described_class.new(target: 1, max: 4)
      admitted = Queue.new
      workers = Array.new(3) { acquirer(gate, admitted) }

      admitted.pop
      wait_until { gate.waiting == 2 }
      expect(gate.active).to eq(1)

      gate.target = 3
      2.times { admitted.pop }
      expect(gate.active).to eq(3)
      expect(gate.waiting).to eq(0)

      workers.each(&:release_and_join)
    end
  end

  describe "shrinking the target" do
    it "stops admitting until enough workers have released" do
      gate = described_class.new(target: 3, max: 4)
      admitted = Queue.new
      workers = Array.new(3) { acquirer(gate, admitted) }

      3.times { admitted.pop }
      expect(gate.active).to eq(3)

      gate.target = 1
      latecomer = acquirer(gate, admitted)
      wait_until { gate.waiting == 1 }

      # Each release is joined, so the permit is back before the asserts run.
      workers[0].release_and_join
      expect(gate.active).to eq(2)
      expect(gate.waiting).to eq(1)

      workers[1].release_and_join
      expect(gate.active).to eq(1)
      expect(gate.waiting).to eq(1)

      workers[2].release_and_join # active drops below the new target of 1
      expect(admitted.pop).to eq(latecomer)

      latecomer.release_and_join
      expect(gate.active).to eq(0)
    end
  end
end

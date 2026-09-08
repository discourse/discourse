# frozen_string_literal: true

RSpec.describe Migrations::Importer::Uploads::WorkerGate do
  # Spawns a worker that acquires a permit, announces itself on `admitted`, then
  # parks until the test pushes to `hold` and releases. Blocking pops act as
  # latches, so the test never sleeps: `admitted.pop` returns exactly when a
  # worker got in, and `expect(admitted).to be_empty` shows one is still parked.
  def acquirer(gate, admitted, hold)
    Thread.new do
      Thread.current.report_on_exception = false
      gate.acquire
      admitted << :in
      hold.pop
      gate.release
    end
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
      hold = Queue.new
      threads = Array.new(3) { acquirer(gate, admitted, hold) }

      2.times { expect(admitted.pop).to eq(:in) }
      expect(admitted).to be_empty # the third is blocked at the target
      expect(gate.active).to eq(2)
      expect(gate.waiting).to eq(1)

      hold << :go # one admitted worker releases; the blocked one wakes
      expect(admitted.pop).to eq(:in)
      expect(gate.active).to eq(2)

      2.times { hold << :go }
      threads.each(&:join)
      expect(gate.active).to eq(0)
    end
  end

  describe "growing the target" do
    it "wakes parked workers so they take the new slots" do
      gate = described_class.new(target: 1, max: 4)
      admitted = Queue.new
      hold = Queue.new
      threads = Array.new(3) { acquirer(gate, admitted, hold) }

      expect(admitted.pop).to eq(:in)
      expect(admitted).to be_empty
      expect(gate.waiting).to eq(2)

      gate.target = 3
      2.times { expect(admitted.pop).to eq(:in) }
      expect(gate.active).to eq(3)

      3.times { hold << :go }
      threads.each(&:join)
    end
  end

  describe "shrinking the target" do
    it "stops admitting until enough workers have released" do
      gate = described_class.new(target: 3, max: 4)
      admitted = Queue.new
      hold = Queue.new
      threads = Array.new(3) { acquirer(gate, admitted, hold) }

      3.times { expect(admitted.pop).to eq(:in) }
      expect(gate.active).to eq(3)

      gate.target = 1

      # A newcomer must wait until active drops below the new target of 1.
      latecomer_admitted = Queue.new
      latecomer_hold = Queue.new
      threads << acquirer(gate, latecomer_admitted, latecomer_hold)

      hold << :go # active 3 -> 2, still >= 1, newcomer stays blocked
      expect(latecomer_admitted).to be_empty
      hold << :go # active 2 -> 1, still >= 1, newcomer stays blocked
      expect(latecomer_admitted).to be_empty

      hold << :go # active 1 -> 0, newcomer finally gets in
      expect(latecomer_admitted.pop).to eq(:in)

      latecomer_hold << :go
      threads.each(&:join)
    end
  end
end

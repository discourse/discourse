# frozen_string_literal: true

RSpec.describe Migrations::Conversion::StepPlan do
  # Builds named step classes in a throwaway namespace so `depends_on` (which
  # resolves names lexically) and the class-name tie-break have real classes to
  # work with. `stub_const` removes them after the example.
  def define_steps(*names, partitionable: [])
    namespace = Module.new
    names.each do |name|
      step_class =
        Class.new(Migrations::Conversion::Step) do
          if partitionable.include?(name)
            source do
              partition_by :id, from: "things"

              def items
                []
              end
            end
          end
        end
      namespace.const_set(name, step_class)
    end
    stub_const("TempSteps", namespace)
    names.map { |name| namespace.const_get(name) }
  end

  # startable returns [[step_class, forks], ...]; compare by demodulized name.
  def names(startable)
    startable.map { |step_class, _forks| step_class.name.demodulize }
  end

  describe "#budget" do
    it "uses the plain budget when nothing caps it" do
      expect(described_class.new(step_classes: [], budget: 4).budget).to eq(4)
    end

    it "takes the lower of the budget and max_parallel_steps" do
      expect(described_class.new(step_classes: [], budget: 4, max_parallel_steps: 2).budget).to eq(
        2,
      )
      expect(described_class.new(step_classes: [], budget: 2, max_parallel_steps: 5).budget).to eq(
        2,
      )
    end

    it "never drops below one" do
      expect(described_class.new(step_classes: [], budget: 0).budget).to eq(1)
    end

    it "is one for an inline (no-fork) run whatever the budget" do
      expect(described_class.new(step_classes: [], budget: 8, no_fork: true).budget).to eq(1)
    end
  end

  describe "#startable" do
    it "starts a step only once its dependencies are done" do
      a, b = define_steps(:A, :B)
      b.depends_on(:a)
      plan = described_class.new(step_classes: [a, b], budget: 4)

      expect(names(plan.startable)).to eq(%w[A])
      expect(names(plan.startable)).to eq([]) # B still waiting, A already running

      plan.step_finished(a, :done)
      expect(names(plan.startable)).to eq(%w[B])
    end

    it "admits ready steps in name order on an empty graph" do
      c, a, b = define_steps(:C, :A, :B)
      plan = described_class.new(step_classes: [c, a, b], budget: 1)

      expect(names(plan.startable)).to eq(%w[A])
      plan.step_finished(a, :done)
      expect(names(plan.startable)).to eq(%w[B])
      plan.step_finished(b, :done)
      expect(names(plan.startable)).to eq(%w[C])
    end

    it "admits lower priority first, then unset priority, before the name tie-break" do
      a, b, c = define_steps(:A, :B, :C)
      a.priority 5
      c.priority 1
      # B has no priority. Order: C (1), A (5), then B (unset, last).
      plan = described_class.new(step_classes: [a, b, c], budget: 1)

      expect(names(plan.startable)).to eq(%w[C])
      plan.step_finished(c, :done)
      expect(names(plan.startable)).to eq(%w[A])
      plan.step_finished(a, :done)
      expect(names(plan.startable)).to eq(%w[B])
    end

    # Each of the next four pins one tier of the admission order in isolation:
    # the loser's name is chosen to win the tie-break, so if that tier stops
    # deciding the order flips and the example fails.

    it "admits a partitioned step ahead of a single-fork step" do
      part, single = define_steps(:B, :A, partitionable: %i[B])
      plan = described_class.new(step_classes: [part, single], budget: 1)

      expect(names(plan.startable)).to eq(%w[B]) # partitioned first, though "A" < "B"
    end

    it "admits a step with a priority ahead of one without" do
      with, without = define_steps(:Z, :A)
      with.priority 5
      plan = described_class.new(step_classes: [with, without], budget: 1)

      expect(names(plan.startable)).to eq(%w[Z]) # has a priority, though "A" < "Z"
    end

    it "admits the lower priority first" do
      high, low = define_steps(:A, :B)
      high.priority 9
      low.priority 1
      plan = described_class.new(step_classes: [high, low], budget: 1)

      expect(names(plan.startable)).to eq(%w[B]) # priority 1 before 9, though "A" < "B"
    end

    it "ignores dependencies that are not part of this run" do
      a, b = define_steps(:A, :B)
      b.depends_on(:a)
      # `a` is left out of the run, so B's dependency on it does not gate it.
      plan = described_class.new(step_classes: [b], budget: 4)

      expect(names(plan.startable)).to eq(%w[B])
    end

    it "never starts more forks than the budget" do
      a, b, c, d = define_steps(:A, :B, :C, :D)
      plan = described_class.new(step_classes: [a, b, c, d], budget: 2)

      expect(names(plan.startable)).to eq(%w[A B])
      expect(names(plan.startable)).to eq([]) # budget full

      plan.step_finished(a, :done)
      expect(names(plan.startable)).to eq(%w[C])
    end

    it "gives a partitioned step all but one fork and lets a single-fork step fill the rest" do
      big, x, y = define_steps(:Big, :X, :Y, partitionable: %i[Big])
      plan = described_class.new(step_classes: [big, x, y], budget: 4)

      started = plan.startable
      expect(names(started)).to eq(%w[Big X])
      expect(started.to_h.transform_keys { |k| k.name.demodulize }).to eq("Big" => 3, "X" => 1)
      expect(names(plan.startable)).to eq([]) # no forks left for Y
    end

    it "gives a single-fork step exactly one fork" do
      a, = define_steps(:A)
      plan = described_class.new(step_classes: [a], budget: 4)

      expect(plan.startable).to eq([[a, 1]])
    end

    it "clamps a partitioned step to one fork when the budget is one" do
      big, = define_steps(:Big, partitionable: %i[Big])
      plan = described_class.new(step_classes: [big], budget: 1)

      expect(plan.startable).to eq([[big, 1]]) # budget - 1 would be zero, floored to one
    end

    it "runs a single-fork step beside a partitioned step while a second partitioned step waits" do
      big_a, big_b, c = define_steps(:BigA, :BigB, :C, partitionable: %i[BigA BigB])
      plan = described_class.new(step_classes: [big_a, big_b, c], budget: 4)

      started = plan.startable.to_h.transform_keys { |step_class| step_class.name.demodulize }
      # BigA holds all but one fork; two partitioned steps never overlap, so BigB
      # waits and C takes the free fork instead of BigB.
      expect(started).to eq("BigA" => 3, "C" => 1)
    end

    it "detects an already-running partitioned step on a later call" do
      big_a, trigger, big_b, c =
        define_steps(:BigA, :Trigger, :BigB, :C, partitionable: %i[BigA BigB])
      big_b.depends_on(:trigger)
      c.depends_on(:trigger)
      plan = described_class.new(step_classes: [big_a, trigger, big_b, c], budget: 4)

      first = plan.startable.to_h.transform_keys { |step_class| step_class.name.demodulize }
      expect(first).to eq("BigA" => 3, "Trigger" => 1)

      plan.step_finished(trigger, :done) # frees one fork; BigB and C become ready

      # BigA is still running and partitioned, so the freed fork goes to the
      # single-fork C; BigB waits for the whole budget to come free.
      expect(names(plan.startable)).to eq(%w[C])
    end

    it "lets a single-fork step use a running partitioned step's freed fork" do
      big, x, y = define_steps(:Big, :X, :Y, partitionable: %i[Big])
      plan = described_class.new(step_classes: [big, x, y], budget: 4)

      plan.startable # Big (3 forks) + X (1 fork)
      plan.release_forks(big, 1)

      expect(names(plan.startable)).to eq(%w[Y])
    end

    it "holds a fork back so a waiting partitioned step can gather the budget" do
      a, big, c, d, e = define_steps(:A, :Big, :C, :D, :E, partitionable: %i[Big])
      big.depends_on(:a)
      plan = described_class.new(step_classes: [a, big, c, d, e], budget: 3)

      expect(names(plan.startable)).to eq(%w[A C D]) # budget full, Big waits on A

      plan.step_finished(a, :done) # one fork free, Big now ready but needs two
      expect(names(plan.startable)).to eq([]) # E held back rather than taking Big's fork

      plan.step_finished(c, :done) # a second fork frees
      expect(names(plan.startable)).to eq(%w[Big])
    end
  end

  describe "#release_forks" do
    it "returns freed forks to the budget so more steps can start" do
      big, x, y = define_steps(:Big, :X, :Y, partitionable: %i[Big])
      plan = described_class.new(step_classes: [big, x, y], budget: 4)
      plan.startable

      expect(plan.release_forks(big, 1)).to eq(1)
      expect(names(plan.startable)).to eq(%w[Y])
    end

    it "frees forks one at a time, capped at what the step holds" do
      big, = define_steps(:Big, partitionable: %i[Big])
      plan = described_class.new(step_classes: [big], budget: 4)
      plan.startable # Big holds 3 forks

      expect(plan.release_forks(big, 1)).to eq(1)
      expect(plan.release_forks(big, 2)).to eq(2)
      expect(plan.release_forks(big, 1)).to eq(0) # nothing left to return
    end

    it "never returns more than the step still holds" do
      big, = define_steps(:Big, partitionable: %i[Big])
      plan = described_class.new(step_classes: [big], budget: 4)
      plan.startable # Big holds 3 forks

      expect(plan.release_forks(big, 10)).to eq(3)
    end

    it "returns zero when asked to free none" do
      big, = define_steps(:Big, partitionable: %i[Big])
      plan = described_class.new(step_classes: [big], budget: 4)
      plan.startable

      expect(plan.release_forks(big, 0)).to eq(0)
    end

    it "returns zero for a step that holds no forks" do
      a, = define_steps(:A)
      plan = described_class.new(step_classes: [a], budget: 2)

      expect(plan.release_forks(a, 1)).to eq(0)
    end
  end

  describe "#step_finished" do
    it "returns the step's remaining forks to the budget" do
      a, b, c = define_steps(:A, :B, :C)
      plan = described_class.new(step_classes: [a, b, c], budget: 1)
      plan.startable # A running, holds the one fork

      plan.step_finished(a, :done)
      expect(names(plan.startable)).to eq(%w[B]) # fork came back
    end

    it "skips a failed step's dependents, transitively" do
      a, b, c, d = define_steps(:A, :B, :C, :D)
      b.depends_on(:a)
      c.depends_on(:b)
      plan = described_class.new(step_classes: [a, b, c, d], budget: 4)

      expect(names(plan.startable)).to eq(%w[A D]) # independent step runs alongside A

      plan.step_finished(a, :failed)

      expect(plan.skipped_steps).to contain_exactly(b, c) # dependents skipped, D untouched
    end

    it "does not skip dependents when the step succeeded" do
      a, b = define_steps(:A, :B)
      b.depends_on(:a)
      plan = described_class.new(step_classes: [a, b], budget: 4)
      plan.startable

      plan.step_finished(a, :done)

      expect(plan.skipped_steps).to be_empty
    end

    it "does not skip an unrelated pending step when another step fails" do
      a, z = define_steps(:A, :Z)
      plan = described_class.new(step_classes: [a, z], budget: 1)

      expect(names(plan.startable)).to eq(%w[A]) # budget of one: Z stays pending
      plan.step_finished(a, :failed)

      expect(plan.skipped_steps).to be_empty # Z depends on nothing that failed
      expect(names(plan.startable)).to eq(%w[Z]) # so it still runs
    end

    it "does not skip a pending step whose own dependency succeeded" do
      y, b, x = define_steps(:Y, :B, :X)
      b.depends_on(:y)
      plan = described_class.new(step_classes: [y, b, x], budget: 4)
      plan.startable # Y and X run; B waits on Y

      plan.step_finished(y, :done) # B is now ready but still pending
      plan.step_finished(x, :failed) # an unrelated failure runs the skip pass

      expect(plan.skipped_steps).to be_empty # B's only dependency succeeded
    end

    it "skips a step when any one of its dependencies failed, not only when all did" do
      a, b, c = define_steps(:A, :B, :C)
      c.depends_on(:a)
      c.depends_on(:b)
      plan = described_class.new(step_classes: [a, b, c], budget: 4)
      plan.startable

      plan.step_finished(a, :done) # one dependency fine...
      plan.step_finished(b, :failed) # ...the other failed

      expect(plan.skipped_steps).to eq([c])
    end
  end

  describe "#finished?" do
    it "is true only once every step reached a terminal state" do
      a, b = define_steps(:A, :B)
      plan = described_class.new(step_classes: [a, b], budget: 4)
      plan.startable

      expect(plan).not_to be_finished
      plan.step_finished(a, :done)
      expect(plan).not_to be_finished
      plan.step_finished(b, :skipped)
      expect(plan).to be_finished
    end
  end

  describe "outcome reporting" do
    it "counts totals, failures and skips" do
      a, b, c = define_steps(:A, :B, :C)
      b.depends_on(:a)
      plan = described_class.new(step_classes: [a, b, c], budget: 4)
      plan.startable
      plan.step_finished(a, :failed) # skips B
      plan.step_finished(c, :done)

      expect(plan.outcome_counts).to eq(total: 3, failed: 1, skipped: 1)
      expect(plan.failed_steps).to eq([a])
      expect(plan.skipped_steps).to eq([b])
    end
  end
end

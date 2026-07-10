# frozen_string_literal: true

RSpec.describe Migrations::Importer::Uploads::AdaptiveController do
  Reading = Migrations::Importer::Uploads::ResourceSampler::Reading
  WorkerGate = Migrations::Importer::Uploads::WorkerGate
  GB = 1024**3

  # A sampler whose reading the test sets before each tick.
  class ScriptedSampler
    attr_accessor :reading

    def sample
      @reading
    end
  end

  def reading(cpu:, mem_fraction: 0.9, mem_bytes: 32 * GB)
    Reading.new(cpu_busy: cpu, memory_fraction: mem_fraction, memory_bytes: mem_bytes)
  end

  # Builds a controller wired to a real gate, a scripted sampler, and mutable
  # `state` (time, completed, work) the test drives by hand — no real thread, no
  # sleeping. Returns everything the tests poke at.
  def build(target:, ceiling:, **reading_opts)
    gate = WorkerGate.new(target:, max: ceiling)
    sampler = ScriptedSampler.new
    sampler.reading = reading(cpu: 0.1, **reading_opts)
    step = instance_double(Migrations::Reporting::Reporter::StepHandle)
    allow(step).to receive(:report_concurrency)
    state = { time: 0.0, completed: 0, work: true }

    controller =
      described_class.new(
        gate:,
        sampler:,
        step:,
        ceiling:,
        work_available: -> { state[:work] },
        completed_count: -> { state[:completed] },
        clock: -> { state[:time] },
      )

    { controller:, gate:, sampler:, state:, step: }
  end

  # Advances the clock and completed count so the next tick sees `rate` items/s.
  def advance(state, seconds: 1.0, rate: 0.0)
    state[:time] += seconds
    state[:completed] += (rate * seconds).to_i
  end

  describe ".plan" do
    it "seeds from today's heuristic and caps by the store factor on a local store" do
      plan =
        described_class.plan(
          usable_cpus: 8,
          store_external: false,
          ar_pool_size: 100,
          fd_limit: 65_536,
        )

      expect(plan.seed).to eq(12) # 8 * 1.5 * 1
      expect(plan.ceiling).to eq(32) # 4 * 8, tighter than the pool and fds
      expect(plan.floor).to eq(2)
    end

    it "seeds higher and allows many more workers against an external store" do
      plan =
        described_class.plan(
          usable_cpus: 8,
          store_external: true,
          ar_pool_size: 100,
          fd_limit: 65_536,
        )

      expect(plan.seed).to eq(24) # 8 * 1.5 * 2
      expect(plan.ceiling).to eq(92) # pool (100 - 8) is now the tightest
    end

    it "lets the AR pool size cap the ceiling and pull the seed down with it" do
      plan =
        described_class.plan(
          usable_cpus: 8,
          store_external: false,
          ar_pool_size: 14,
          fd_limit: 65_536,
        )

      expect(plan.ceiling).to eq(6) # 14 - 8 reserved
      expect(plan.seed).to eq(6) # clamped down from 12
    end

    it "lets a low file-descriptor limit cap the ceiling" do
      plan =
        described_class.plan(
          usable_cpus: 8,
          store_external: false,
          ar_pool_size: 100,
          fd_limit: 304,
        )

      expect(plan.ceiling).to eq(3) # (304 - 256) / 16
    end

    it "never drops the ceiling or seed below the floor" do
      plan =
        described_class.plan(
          usable_cpus: 1,
          store_external: false,
          ar_pool_size: 8,
          fd_limit: 65_536,
        )

      expect(plan.ceiling).to eq(2)
      expect(plan.seed).to eq(2)
    end
  end

  describe "memory policy" do
    it "halves the target below the normal floor and freezes increases in an emergency" do
      h = build(target: 3, ceiling: 16)
      h[:sampler].reading = reading(cpu: 0.1, mem_fraction: 0.05, mem_bytes: GB / 2)

      h[:controller].tick
      expect(h[:gate].target).to eq(1) # 3 / 2 = 1, below the floor of 2 on purpose

      # Even with the box now healthy and work waiting, the freeze holds the target
      # for several ticks before the controller probes upward again.
      h[:sampler].reading = reading(cpu: 0.1)
      4.times do |i|
        advance(h[:state], rate: 100)
        h[:controller].tick
        expect(h[:gate].target).to eq(1), "grew too early on freeze tick #{i}"
      end

      advance(h[:state], rate: 100)
      h[:controller].tick
      expect(h[:gate].target).to be > 1 # freeze lifted, probing resumes
    end

    it "blocks increases while memory is merely low, without shrinking" do
      h = build(target: 4, ceiling: 16, mem_fraction: 0.20, mem_bytes: GB)

      advance(h[:state], rate: 100)
      h[:controller].tick

      expect(h[:gate].target).to eq(4) # caution: no growth, but no shrink either
    end

    it "ignores a low fraction while plenty of memory is absolutely available" do
      # A huge-RAM server: 5% free is still 8 GB — not pressure. The fraction
      # threshold only binds when the absolute one agrees.
      h = build(target: 4, ceiling: 16, mem_fraction: 0.05, mem_bytes: 8 * GB)

      advance(h[:state], rate: 100)
      h[:controller].tick

      expect(h[:gate].target).to be > 4 # neither emergency nor caution: it probes
    end
  end

  describe "CPU policy" do
    it "backs off when the CPU is saturated, then cools down before probing again" do
      h = build(target: 16, ceiling: 32)
      h[:sampler].reading = reading(cpu: 0.97)

      h[:controller].tick
      expect(h[:gate].target).to eq(14) # 16 - max(16/8, 1) = 14

      # Cooldown: in-flight subprocesses lag the signal, so hold for a tick.
      h[:sampler].reading = reading(cpu: 0.1)
      advance(h[:state], rate: 100)
      h[:controller].tick
      expect(h[:gate].target).to eq(14)

      advance(h[:state], rate: 100)
      h[:controller].tick
      expect(h[:gate].target).to be > 14 # cooldown elapsed
    end
  end

  describe "increasing" do
    it "does nothing while the producer is the bottleneck (empty work queue)" do
      h = build(target: 4, ceiling: 16)
      h[:state][:work] = false

      advance(h[:state], rate: 100)
      h[:controller].tick

      expect(h[:gate].target).to eq(4)
    end

    it "jumps by 4 when the box is idle and by 1 when it is busy" do
      idle = build(target: 4, ceiling: 32)
      advance(idle[:state], rate: 100)
      idle[:controller].tick
      expect(idle[:gate].target).to eq(8) # +4 at cpu 0.1

      busy = build(target: 4, ceiling: 32, mem_fraction: 0.9)
      busy[:sampler].reading = reading(cpu: 0.7)
      advance(busy[:state], rate: 100)
      busy[:controller].tick
      expect(busy[:gate].target).to eq(5) # +1 at cpu 0.7
    end

    it "reverts and holds after two probes that each buy less than 5% throughput" do
      h = build(target: 4, ceiling: 32)

      advance(h[:state], seconds: 1.0, rate: 100) # baseline rate 100/s
      h[:controller].tick
      expect(h[:gate].target).to eq(8) # first probe

      advance(h[:state], seconds: 1.0, rate: 100) # still 100/s -> no gain
      h[:controller].tick
      expect(h[:gate].target).to eq(12) # second probe, first low-gain result

      advance(h[:state], seconds: 1.0, rate: 100) # still flat -> plateau
      h[:controller].tick
      expect(h[:gate].target).to eq(8) # reverts the last +4 step

      # And it holds: no probing for a while even though everything looks inviting.
      advance(h[:state], seconds: 1.0, rate: 100)
      h[:controller].tick
      expect(h[:gate].target).to eq(8)
    end

    it "keeps probing when each increase actually pays off" do
      h = build(target: 4, ceiling: 32)

      advance(h[:state], seconds: 1.0, rate: 100)
      h[:controller].tick
      expect(h[:gate].target).to eq(8)

      advance(h[:state], seconds: 1.0, rate: 200) # doubled -> big gain
      h[:controller].tick
      expect(h[:gate].target).to eq(12)

      advance(h[:state], seconds: 1.0, rate: 400) # doubled again
      h[:controller].tick
      expect(h[:gate].target).to eq(16) # no revert; streak reset by the gains
    end
  end

  describe "#start / #stop" do
    it "runs ticks on a background thread and stops cleanly" do
      h = build(target: 2, ceiling: 16)
      ticks = Queue.new
      allow(h[:controller]).to receive(:tick) { ticks << :tick }

      h[:controller].instance_variable_set(:@interval, 0.001)
      h[:controller].start
      ticks.pop # at least one tick ran
      expect { h[:controller].stop }.not_to raise_error
    end
  end
end

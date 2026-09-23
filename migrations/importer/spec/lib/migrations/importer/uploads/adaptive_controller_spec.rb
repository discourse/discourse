# frozen_string_literal: true

RSpec.describe Migrations::Importer::Uploads::AdaptiveController do
  let(:gb) { 1024**3 }
  let(:window) { described_class::PROBE_GRADE_TICKS }
  let(:fast_step) { described_class::INCREASE_STEP_FAST }

  # A sampler whose reading the test sets before each tick.
  let(:scripted_sampler_class) do
    Struct.new(:reading) do
      def sample
        reading
      end
    end
  end

  def reading(cpu:, mem_fraction: 0.9, mem_bytes: 32 * gb)
    Migrations::Importer::Uploads::ResourceSampler::Reading.new(
      cpu_busy: cpu,
      memory_fraction: mem_fraction,
      memory_bytes: mem_bytes,
    )
  end

  # Builds a controller wired to a real gate, a scripted sampler, and mutable
  # `state` (time, completed, work) the test drives by hand — no real thread, no
  # sleeping. Returns everything the tests poke at.
  def build(
    target:,
    ceiling:,
    sampler: nil,
    interval: described_class::DEFAULT_INTERVAL,
    **reading_opts
  )
    gate = Migrations::Importer::Uploads::WorkerGate.new(target:, max: ceiling)
    unless sampler
      sampler = scripted_sampler_class.new
      sampler.reading = reading(cpu: 0.1, **reading_opts)
    end
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
        interval:,
        clock: -> { state[:time] },
      )

    { controller:, gate:, sampler:, state:, step: }
  end

  # Advances the clock and completed count so the next tick sees `rate` items/s.
  def advance(state, seconds: 1.0, rate: 0.0)
    state[:time] += seconds
    state[:completed] += (rate * seconds).to_i
  end

  # One tick per rate, each a second apart.
  def run_ticks(h, *rates)
    rates.each do |rate|
      advance(h[:state], rate:)
      h[:controller].tick
    end
  end

  describe ".plan" do
    it "seeds from the CPU count and caps by the store factor on a local store" do
      plan =
        described_class.plan(
          usable_cpus: 8,
          store_external: false,
          ar_pool_size: 100,
          fd_limit: 65_536,
        )

      expect(plan.seed).to eq(12) # 8 * 1.5 * 1
      expect(plan.ceiling).to eq(32) # 4 * 8, tighter than the pool and fds
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
      h[:sampler].reading = reading(cpu: 0.1, mem_fraction: 0.05, mem_bytes: gb / 2)

      h[:controller].tick
      expect(h[:gate].target).to eq(1) # 3 / 2 = 1, below the floor of 2 on purpose

      # Even with the machine now healthy and work waiting, the freeze holds the target
      # for several ticks before the controller probes upward again.
      h[:sampler].reading = reading(cpu: 0.1)
      4.times do |i|
        run_ticks(h, 100)
        expect(h[:gate].target).to eq(1), "grew too early on freeze tick #{i}"
      end

      run_ticks(h, 100)
      expect(h[:gate].target).to be > 1 # freeze lifted, probing resumes
    end

    it "blocks increases while memory is merely low, without shrinking" do
      h = build(target: 4, ceiling: 16, mem_fraction: 0.20, mem_bytes: gb)

      run_ticks(h, *[100] * window)

      expect(h[:gate].target).to eq(4) # caution: no growth, but no shrink either
    end

    it "ignores a low fraction while plenty of memory is absolutely available" do
      # A huge-RAM server: 5% free is still 8 GB — not pressure. The fraction
      # threshold only binds when the absolute one agrees.
      h = build(target: 4, ceiling: 16, mem_fraction: 0.05, mem_bytes: 8 * gb)

      run_ticks(h, *[100] * window)

      expect(h[:gate].target).to be > 4 # neither emergency nor caution: it probes
    end
  end

  describe "CPU policy" do
    it "backs off when the CPU is saturated, then cools down before probing again" do
      h = build(target: 16, ceiling: 32)
      h[:sampler].reading = reading(cpu: 0.97)

      h[:controller].tick
      expect(h[:gate].target).to eq(14) # 16 - max(16/8, 1) = 14

      # Cooldown, then a fresh throughput window at the new target, before it
      # probes again.
      h[:sampler].reading = reading(cpu: 0.1)
      run_ticks(h, *[100] * (window - 1))
      expect(h[:gate].target).to eq(14)

      run_ticks(h, 100)
      expect(h[:gate].target).to be > 14
    end

    it "never raises a target that a memory emergency pushed below the floor" do
      h = build(target: 3, ceiling: 16)
      h[:sampler].reading = reading(cpu: 0.1, mem_fraction: 0.05, mem_bytes: gb / 2)
      h[:controller].tick
      expect(h[:gate].target).to eq(1)

      h[:sampler].reading = reading(cpu: 0.99)
      run_ticks(h, 100, 100)

      expect(h[:gate].target).to eq(1)
    end
  end

  describe "increasing" do
    it "does nothing while the producer is the bottleneck (empty work queue)" do
      h = build(target: 4, ceiling: 16)
      h[:state][:work] = false

      run_ticks(h, *[100] * window)

      expect(h[:gate].target).to eq(4)
    end

    it "waits for a full throughput window before the first probe" do
      h = build(target: 4, ceiling: 32)

      run_ticks(h, *[100] * (window - 1))
      expect(h[:gate].target).to eq(4)

      run_ticks(h, 100)
      expect(h[:gate].target).to eq(8)
    end

    it "jumps by 4 when the CPU is idle and by 1 when it is busy" do
      idle = build(target: 4, ceiling: 32)
      run_ticks(idle, *[100] * window)
      expect(idle[:gate].target).to eq(8) # +4 at cpu 0.1

      busy = build(target: 4, ceiling: 32)
      busy[:sampler].reading = reading(cpu: 0.7)
      run_ticks(busy, *[100] * window)
      expect(busy[:gate].target).to eq(5) # +1 at cpu 0.7
    end

    it "keeps probing when each increase actually pays off" do
      h = build(target: 4, ceiling: 32)

      run_ticks(h, *[100] * window)
      expect(h[:gate].target).to eq(8)

      run_ticks(h, *[200] * window) # doubled -> big gain
      expect(h[:gate].target).to eq(12)

      run_ticks(h, *[400] * window) # doubled again
      expect(h[:gate].target).to eq(16) # no revert; streak reset by the gains
    end

    it "grades a probe on the whole window, not on a single noisy tick" do
      h = build(target: 4, ceiling: 32)
      run_ticks(h, *[100] * window)
      expect(h[:gate].target).to eq(8)

      # Completions arrive in bursts; single ticks read 0 while the window as a
      # whole is 10% up.
      run_ticks(h, 0, 0)
      expect(h[:gate].target).to eq(8) # not graded yet
      run_ticks(h, 330)
      expect(h[:gate].target).to eq(12)

      run_ticks(h, 0, 0, 363)
      expect(h[:gate].target).to eq(16) # two bursty gains, no plateau
    end

    it "treats a zero baseline as no information, neither gain nor loss" do
      h = build(target: 4, ceiling: 32)
      run_ticks(h, *[100] * window)
      expect(h[:gate].target).to eq(8)

      run_ticks(h, *[0] * window) # weak probe: streak 1, next probe starts from zero
      expect(h[:gate].target).to eq(12)

      run_ticks(h, *[100] * window) # zero baseline: must not reset the streak
      expect(h[:gate].target).to eq(16)

      run_ticks(h, *[100] * window) # weak again: streak 2 -> plateau
      expect(h[:gate].target).to eq(4)
    end
  end

  describe "plateau" do
    it "reverts to the target from before the weak streak and holds there" do
      h = build(target: 4, ceiling: 32)

      run_ticks(h, *[100] * window)
      expect(h[:gate].target).to eq(8) # first probe

      run_ticks(h, *[100] * window) # flat -> first weak probe
      expect(h[:gate].target).to eq(12) # second probe

      run_ticks(h, *[100] * window) # still flat -> plateau
      expect(h[:gate].target).to eq(4) # both weak steps undone

      hold_ticks = described_class::PLATEAU_HOLD_SECONDS - 1
      hold_ticks.times do |i|
        run_ticks(h, 100)
        expect(h[:gate].target).to eq(4), "moved during the hold on tick #{i}"
      end
    end

    it "does not drift upward over many plateau cycles at flat throughput" do
      h = build(target: 4, ceiling: 64)
      targets = []

      400.times do
        run_ticks(h, 100)
        targets << h[:gate].target
      end

      # A weak streak can briefly reach PLATEAU_LOW_GAIN_LIMIT steps above the
      # pre-streak target, but every cycle returns to it.
      expect(targets.max).to eq(4 + described_class::PLATEAU_LOW_GAIN_LIMIT * fast_step)
      expect(targets.last(described_class::PLATEAU_HOLD_SECONDS)).to include(4)
      expect(targets.count(4)).to be > targets.size / 2
    end

    it "keeps an earlier probe that paid off when a later streak reverts" do
      h = build(target: 4, ceiling: 32)

      run_ticks(h, *[100] * window)
      run_ticks(h, *[200] * window) # gain: 8 stays, probe to 12
      run_ticks(h, *[200] * window) # weak, probe to 16
      run_ticks(h, *[200] * window) # weak again -> back to 8

      expect(h[:gate].target).to eq(8)
    end
  end

  describe "#start / #stop" do
    # Records each sample on a queue so the test can wait for real ticks.
    let(:recording_sampler_class) do
      Struct.new(:ticks, :reading, :failures) do
        def sample
          ticks << :tick
          if failures > 0
            self.failures -= 1
            raise "sampler exploded"
          end
          reading
        end
      end
    end

    it "runs ticks on a background thread and stops cleanly" do
      sampler = recording_sampler_class.new(Queue.new, reading(cpu: 0.1), 0)
      h = build(target: 2, ceiling: 16, sampler:, interval: 0.001)

      h[:controller].start
      sampler.ticks.pop # at least one tick ran
      expect { h[:controller].stop }.not_to raise_error
    end

    it "reports a failing tick once and keeps ticking" do
      sampler = recording_sampler_class.new(Queue.new, reading(cpu: 0.1), 2)
      h = build(target: 2, ceiling: 16, sampler:, interval: 0.001)
      allow(h[:step]).to receive(:notice)

      h[:controller].start
      4.times { sampler.ticks.pop } # past both failures, so the loop survived them
      h[:controller].stop

      expect(h[:step]).to have_received(:notice).once.with(/sampler exploded/)
    end
  end
end

# frozen_string_literal: true

RSpec.describe Migrations::Importer::Uploads::AdaptiveController do
  let(:gb) { 1024**3 }
  let(:window) { described_class::PROBE_GRADE_TICKS }

  let(:scripted_sampler_class) do
    Struct.new(:reading) do
      def sample
        reading
      end
    end
  end

  def reading(cpu: 0.1, mem_fraction: 0.9, mem_bytes: 32 * gb)
    Migrations::Importer::Uploads::ResourceSampler::Reading.new(
      cpu_busy: cpu,
      memory_fraction: mem_fraction,
      memory_bytes: mem_bytes,
    )
  end

  # A controller on a real gate, driven by hand with a fake clock, a scripted
  # sampler and a completed count. No thread and no sleeping.
  def build(
    target:,
    ceiling:,
    sampler: nil,
    interval: described_class::DEFAULT_INTERVAL,
    **reading_opts
  )
    gate = Migrations::Importer::Uploads::WorkerGate.new(target:, max: ceiling)
    sampler ||= scripted_sampler_class.new(reading(**reading_opts))
    step = instance_double(Migrations::Reporting::Reporter::StepHandle, report_concurrency: nil)
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

  # One tick per rate (items finished in that second), one second apart.
  # Returns the target after each tick.
  def run_ticks(h, *rates)
    rates.map do |rate|
      h[:state][:time] += 1.0
      h[:state][:completed] += rate
      h[:controller].tick
      h[:gate].target
    end
  end

  describe ".plan" do
    def plan(**overrides)
      machine = { usable_cpus: 8, store_external: false, ar_pool_size: 100, fd_limit: 65_536 }
      described_class.plan(**machine, **overrides).to_h
    end

    it "seeds from the CPU count and caps the ceiling by the tightest limit" do
      # local store: 8 * 1.5 seed, 4 * 8 ceiling
      expect(plan).to eq(seed: 12, ceiling: 32)
      # external store: seed doubled, the pool (100 - 8) is now the tightest
      expect(plan(store_external: true)).to eq(seed: 24, ceiling: 92)
      # a small pool (14 - 8) pulls the seed down with the ceiling
      expect(plan(ar_pool_size: 14)).to eq(seed: 6, ceiling: 6)
      # a low fd limit: (304 - 256) / 16
      expect(plan(fd_limit: 304)).to eq(seed: 3, ceiling: 3)
      # never below the floor
      expect(plan(usable_cpus: 1, ar_pool_size: 8)).to eq(seed: 2, ceiling: 2)
    end
  end

  describe "memory policy" do
    it "halves the target below the normal floor in an emergency and freezes increases" do
      h = build(target: 3, ceiling: 16, mem_fraction: 0.05, mem_bytes: gb / 2)
      expect(run_ticks(h, 100)).to eq([1])

      h[:sampler].reading = reading
      expect(run_ticks(h, *[100] * 5)).to eq([1, 1, 1, 1, 5])
    end

    it "blocks increases while memory is low, without shrinking" do
      h = build(target: 4, ceiling: 16, mem_fraction: 0.20, mem_bytes: gb)

      expect(run_ticks(h, *[100] * window)).to eq([4, 4, 4])
    end

    it "ignores a low fraction while plenty of memory is available in bytes" do
      h = build(target: 4, ceiling: 16, mem_fraction: 0.05, mem_bytes: 8 * gb)

      expect(run_ticks(h, *[100] * window)).to eq([4, 4, 8])
    end
  end

  describe "CPU policy" do
    it "backs off when the CPU is saturated, then cools down before probing again" do
      h = build(target: 16, ceiling: 32, cpu: 0.97)
      expect(run_ticks(h, 100)).to eq([14]) # 16 - 16 / 8

      h[:sampler].reading = reading
      expect(run_ticks(h, *[100] * window)).to eq([14, 14, 18])
    end

    it "never raises a target that a memory emergency pushed below the floor" do
      h = build(target: 3, ceiling: 16, mem_fraction: 0.05, mem_bytes: gb / 2)
      run_ticks(h, 100)

      h[:sampler].reading = reading(cpu: 0.99)
      expect(run_ticks(h, 100, 100)).to eq([1, 1])
    end
  end

  describe "increasing" do
    it "does nothing while the work queue is empty" do
      h = build(target: 4, ceiling: 16)
      h[:state][:work] = false

      expect(run_ticks(h, *[100] * window)).to eq([4, 4, 4])
    end

    it "waits a full window, then steps up by 4 on an idle CPU and by 1 on a busy one" do
      expect(run_ticks(build(target: 4, ceiling: 32), *[100] * window)).to eq([4, 4, 8])
      expect(run_ticks(build(target: 4, ceiling: 32, cpu: 0.7), *[100] * window)).to eq([4, 4, 5])
    end

    it "keeps probing while each increase raises the throughput" do
      h = build(target: 4, ceiling: 32)

      expect(run_ticks(h, *[100] * window, *[200] * window, *[400] * window)).to eq(
        [4, 4, 8, 8, 8, 12, 12, 12, 16],
      )
    end

    it "grades a probe on the whole window, not on a single tick" do
      h = build(target: 4, ceiling: 32)

      # Completions come in bursts: single ticks read 0, but each window is 10% up.
      expect(run_ticks(h, *[100] * window, 0, 0, 330, 0, 0, 363)).to eq(
        [4, 4, 8, 8, 8, 12, 12, 12, 16],
      )
    end

    it "treats a zero baseline as neither gain nor loss" do
      h = build(target: 4, ceiling: 32)

      # The probe to 8 is weak. The probe to 12 has a zero baseline, so it must
      # not reset the streak, and the weak probe to 16 ends the streak.
      expect(run_ticks(h, *[100] * window, *[0] * window, *[100] * window, *[100] * window)).to eq(
        [4, 4, 8, 8, 8, 12, 12, 12, 16, 16, 16, 4],
      )
    end
  end

  describe "plateau" do
    it "goes back to the target from before the weak probes and holds it" do
      h = build(target: 4, ceiling: 32)
      hold = described_class::PLATEAU_HOLD_SECONDS

      expect(run_ticks(h, *[100] * (3 * window + hold - 1))).to eq(
        [4, 4, 8, 8, 8, 12, 12, 12] + [4] * hold,
      )
    end

    it "does not drift upward over many plateau cycles at flat throughput" do
      h = build(target: 4, ceiling: 64)

      expect(run_ticks(h, *[100] * 400).uniq).to contain_exactly(4, 8, 12)
    end

    it "keeps an earlier probe that raised the throughput when a later streak goes back" do
      h = build(target: 4, ceiling: 32)

      expect(run_ticks(h, *[100] * window, *[200] * (3 * window)).last).to eq(8)
    end
  end

  describe "#start / #stop" do
    # Pushes onto `ticks` on every sample, so the test can wait for real ticks.
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

    it "keeps ticking on a background thread after a failing tick and reports it once" do
      sampler = recording_sampler_class.new(Queue.new, reading, 2)
      h = build(target: 2, ceiling: 16, sampler:, interval: 0.001)
      allow(h[:step]).to receive(:notice)

      h[:controller].start
      4.times { sampler.ticks.pop }
      h[:controller].stop

      expect(h[:step]).to have_received(:notice).once.with(/sampler exploded/)
    end
  end
end

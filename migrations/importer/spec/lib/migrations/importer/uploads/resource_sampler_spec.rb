# frozen_string_literal: true

RSpec.describe Migrations::Importer::Uploads::ResourceSampler do
  # Feeds a fixed sequence of file contents; nil once the list runs out, which is
  # how the real readers report "file not there".
  def sequence(*values)
    list = values.dup
    -> { list.shift }
  end

  def build(**overrides)
    defaults = {
      usable_cpus: 4,
      proc_stat: -> { nil },
      meminfo: -> { nil },
      cgroup_max: -> { nil },
      cgroup_current: -> { nil },
      process_times: -> { Process::Tms.new(0.0, 0.0, 0.0, 0.0) },
      clock: -> { 0.0 },
    }
    described_class.new(**defaults, **overrides)
  end

  describe "CPU from /proc/stat" do
    it "reports the busy fraction over the interval since the last sample" do
      # baseline busy=200 total=1000; next busy=300 total=1200 => 100/200 = 0.5
      proc_stat =
        sequence(
          "cpu  100 0 100 800 0 0 0 0 0 0\nintr 1\n",
          "cpu  150 0 150 900 0 0 0 0 0 0\nintr 1\n",
        )
      sampler = build(proc_stat:)

      expect(sampler.sample.cpu_busy).to be_within(0.001).of(0.5)
    end

    it "counts iowait as idle, not busy" do
      # Only iowait moves (400 jiffies), everything else flat => 0% busy.
      proc_stat = sequence("cpu  100 0 100 800 0 0 0 0 0 0\n", "cpu  100 0 100 800 400 0 0 0 0 0\n")
      sampler = build(proc_stat:)

      expect(sampler.sample.cpu_busy).to eq(0.0)
    end
  end

  describe "CPU fallback via Process.times" do
    it "uses reaped-child CPU time over wall-time times the usable CPUs" do
      # baseline cpu=1.0 at t=0; next cpu=3.0 at t=1; total = 1s * 4 cpus = 4
      # => (3-1) / 4 = 0.5
      times = sequence(Process::Tms.new(1.0, 0.0, 0.0, 0.0), Process::Tms.new(2.0, 0.0, 1.0, 0.0))
      clock = sequence(0.0, 1.0)
      sampler = build(usable_cpus: 4, proc_stat: -> { nil }, process_times: times, clock:)

      expect(sampler.sample.cpu_busy).to be_within(0.001).of(0.5)
    end
  end

  describe "memory" do
    it "reads MemAvailable against MemTotal when there is no cgroup limit" do
      meminfo = -> { "MemTotal:       16000 kB\nMemAvailable:    8000 kB\n" }
      sampler = build(meminfo:)

      reading = sampler.sample
      expect(reading.memory_known?).to be(true)
      expect(reading.memory_fraction).to be_within(0.001).of(0.5)
      expect(reading.memory_bytes).to eq(8000 * 1024)
    end

    it "takes the tighter cgroup v2 headroom when the process is capped" do
      meminfo = -> { "MemTotal:       16000000 kB\nMemAvailable:    8000000 kB\n" }
      sampler =
        build(meminfo:, cgroup_max: -> { "2000000000\n" }, cgroup_current: -> { "1500000000\n" })

      reading = sampler.sample
      # cgroup headroom 500 MB is tighter than the 8 GB host figure.
      expect(reading.memory_bytes).to eq(500_000_000)
      expect(reading.memory_fraction).to be_within(0.001).of(0.25)
    end

    it "ignores an unlimited cgroup (memory.max == 'max')" do
      meminfo = -> { "MemTotal:       16000 kB\nMemAvailable:    4000 kB\n" }
      sampler = build(meminfo:, cgroup_max: -> { "max\n" }, cgroup_current: -> { "1000\n" })

      expect(sampler.sample.memory_fraction).to be_within(0.001).of(0.25)
    end

    it "reports memory as unknown when nothing is readable" do
      reading = build.sample

      expect(reading.memory_known?).to be(false)
      expect(reading.memory_fraction).to be_nil
      expect(reading.memory_bytes).to be_nil
    end
  end

  describe "#total_memory_bytes" do
    it "returns MemTotal in bytes" do
      sampler = build(meminfo: -> { "MemTotal:       16000 kB\nMemAvailable: 8000 kB\n" })

      expect(sampler.total_memory_bytes).to eq(16_000 * 1024)
    end

    it "is nil when meminfo is unreadable" do
      expect(build.total_memory_bytes).to be_nil
    end
  end
end

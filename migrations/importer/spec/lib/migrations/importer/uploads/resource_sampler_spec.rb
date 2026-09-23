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
      cgroup_memory_stat: -> { nil },
      cgroup_cpu_max: -> { nil },
      cgroup_cpu_stat: -> { nil },
      process_times: -> { Process::Tms.new(0.0, 0.0, 0.0, 0.0) },
      clock: -> { 0.0 },
    }
    described_class.new(**defaults, **overrides)
  end

  # Host-wide /proc/stat that always reads as fully idle, to show that the
  # cgroup reading is used instead.
  let(:idle_proc_stat) { sequence("cpu  0 0 0 100 0\n", "cpu  0 0 0 200 0\n") }

  describe "CPU under a cgroup v2 quota" do
    it "measures the cgroup's usage against its quota, not the whole host" do
      # 2 CPUs of quota; 1.5 CPU-seconds used over 1s of wall => 75% busy,
      # while the host-wide /proc/stat says the machine is idle.
      sampler =
        build(
          proc_stat: idle_proc_stat,
          cgroup_cpu_max: -> { "200000 100000\n" },
          cgroup_cpu_stat: sequence("usage_usec 1000000\nuser_usec 1\n", "usage_usec 2500000\n"),
          clock: sequence(10.0, 11.0),
        )

      expect(sampler.sample.cpu_busy).to be_within(0.001).of(0.75)
    end

    it "falls back to /proc/stat when the cgroup has no quota" do
      sampler =
        build(
          proc_stat: sequence("cpu  100 0 100 800 0\n", "cpu  150 0 150 900 0\n"),
          cgroup_cpu_max: -> { "max 100000\n" },
          cgroup_cpu_stat: sequence("usage_usec 0\n", "usage_usec 9000000\n"),
          clock: sequence(0.0, 1.0),
        )

      expect(sampler.sample.cpu_busy).to be_within(0.001).of(0.5)
    end

    it "falls back to /proc/stat when cpu.stat is unreadable" do
      sampler =
        build(
          proc_stat: sequence("cpu  100 0 100 800 0\n", "cpu  150 0 150 900 0\n"),
          cgroup_cpu_max: -> { "200000 100000\n" },
        )

      expect(sampler.sample.cpu_busy).to be_within(0.001).of(0.5)
    end

    it "reads zero rather than mixing units when the source changes between samples" do
      sampler =
        build(
          proc_stat: -> { "cpu  100 0 100 800 0\n" },
          cgroup_cpu_max: -> { "200000 100000\n" },
          cgroup_cpu_stat: sequence("usage_usec 1000000\n"), # gone on the next read
          clock: -> { 5.0 },
        )

      expect(sampler.sample.cpu_busy).to eq(0.0)
    end
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

    it "does not count reclaimable page cache as used cgroup memory" do
      memory_stat = <<~STAT
        anon 600000000
        file 1300000000
        active_file 400000000
        inactive_file 900000000
      STAT
      sampler =
        build(
          cgroup_max: -> { "2000000000\n" },
          cgroup_current: -> { "1900000000\n" },
          cgroup_memory_stat: -> { memory_stat },
        )

      reading = sampler.sample
      # Working set 1.9 GB - 0.9 GB inactive file = 1.0 GB, so 1.0 GB is free
      # rather than the 0.1 GB that memory.current alone suggests.
      expect(reading.memory_bytes).to eq(1_000_000_000)
      expect(reading.memory_fraction).to be_within(0.001).of(0.5)
    end

    it "uses memory.current as is when memory.stat is unreadable" do
      sampler =
        build(
          cgroup_max: -> { "2000000000\n" },
          cgroup_current: -> { "1900000000\n" },
          cgroup_memory_stat: -> { nil },
        )

      expect(sampler.sample.memory_bytes).to eq(100_000_000)
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
end

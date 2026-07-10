# frozen_string_literal: true

module Migrations
  module Importer
    module Uploads
      # Reads how busy the machine is right now, so the {AdaptiveController} can
      # decide whether adding workers is safe. Two independent signals:
      #
      #   * CPU busy fraction. Preferred source is `/proc/stat`, whose first line
      #     counts every process on the box — so it sees the ImageMagick convert
      #     subprocesses and the local Postgres, not just our Ruby threads. Without
      #     procfs (non-Linux dev boxes) it falls back to `Process.times`, which
      #     includes `cutime`/`cstime` (reaped children) spread over the interval
      #     times the usable CPU count.
      #   * Memory headroom. `MemAvailable` from `/proc/meminfo`, tightened by the
      #     cgroup v2 limit (`memory.max` / `memory.current`) when the process runs
      #     under one — a container is usually capped well below the host's RAM.
      #     Returns nil when memory can't be read at all, and the controller then
      #     leaves the memory policy switched off rather than guessing.
      #
      # Every reader is injectable so specs can drive it without touching the real
      # filesystem or sleeping.
      class ResourceSampler
        # One reading. `memory_fraction`/`memory_bytes` are nil when memory is
        # unavailable; {#memory_known?} says whether the controller may act on it.
        Reading =
          Data.define(:cpu_busy, :memory_fraction, :memory_bytes) do
            def memory_known?
              !memory_fraction.nil?
            end
          end

        def initialize(
          usable_cpus:,
          clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) },
          proc_stat: -> { read_file("/proc/stat") },
          meminfo: -> { read_file("/proc/meminfo") },
          cgroup_max: -> { read_file("/sys/fs/cgroup/memory.max") },
          cgroup_current: -> { read_file("/sys/fs/cgroup/memory.current") },
          process_times: -> { Process.times }
        )
          @usable_cpus = usable_cpus
          @clock = clock
          @proc_stat = proc_stat
          @meminfo = meminfo
          @cgroup_max = cgroup_max
          @cgroup_current = cgroup_current
          @process_times = process_times

          # Prime the CPU baseline so the first `sample` measures a real delta over
          # the first interval instead of the whole process lifetime.
          @previous_cpu = cpu_snapshot
        end

        def sample
          fraction, bytes = memory_headroom
          Reading.new(cpu_busy:, memory_fraction: fraction, memory_bytes: bytes)
        end

        # MemTotal in bytes, or nil. Used once at startup to size the ImageMagick
        # memory limits; not part of the per-tick sampling.
        def total_memory_bytes
          meminfo = parse_meminfo
          meminfo && meminfo[:total]
        end

        private

        # Busy fraction (0.0..1.0) over the interval since the last call.
        def cpu_busy
          snapshot = cpu_snapshot
          previous = @previous_cpu
          @previous_cpu = snapshot
          return 0.0 if snapshot.nil? || previous.nil?

          delta_total = snapshot[:total] - previous[:total]
          return 0.0 if delta_total <= 0

          delta_busy = snapshot[:busy] - previous[:busy]
          (delta_busy.to_f / delta_total).clamp(0.0, 1.0)
        end

        # `{ busy:, total: }` in whatever unit the source uses — only the ratio of
        # two snapshots matters, so procfs jiffies and CPU-seconds both work.
        def cpu_snapshot
          from_proc_stat || from_process_times
        end

        def from_proc_stat
          content = @proc_stat.call
          return nil if content.nil?

          fields = content.lines.first.to_s.split
          return nil if fields.shift != "cpu"

          values = fields.map(&:to_i)
          return nil if values.empty?

          idle = values[3].to_i + values[4].to_i # idle + iowait
          total = values.sum
          { busy: total - idle, total: }
        end

        # Wall time times the usable CPUs is the denominator, so the fraction is
        # "of all the cores we may use", matching the procfs reading.
        def from_process_times
          times = @process_times.call
          cpu_seconds = times.utime + times.stime + times.cutime + times.cstime
          { busy: cpu_seconds, total: @clock.call * @usable_cpus }
        end

        # `[fraction, bytes]` for the tightest constraint, or nil when nothing is
        # readable. cgroup v1 is deliberately not supported: its hierarchy layout
        # varies too much to probe reliably, and the migration tooling only ever
        # runs on cgroup v2 hosts (modern Docker/k8s) or bare metal where the
        # host `/proc/meminfo` reading already covers it.
        def memory_headroom
          candidates = []

          if (meminfo = parse_meminfo) && meminfo[:total] > 0
            candidates << [meminfo[:available].to_f / meminfo[:total], meminfo[:available]]
          end

          if (cgroup = cgroup_headroom) && cgroup[:limit] > 0
            candidates << [cgroup[:available].to_f / cgroup[:limit], cgroup[:available]]
          end

          return nil, nil if candidates.empty?

          candidates.min_by { |(_fraction, bytes)| bytes }
        end

        def parse_meminfo
          content = @meminfo.call
          return nil if content.nil?

          total = content[/^MemTotal:\s+(\d+)\s*kB/, 1]
          available = content[/^MemAvailable:\s+(\d+)\s*kB/, 1]
          return nil if total.nil? || available.nil?

          { total: total.to_i * 1024, available: available.to_i * 1024 }
        end

        def cgroup_headroom
          max = @cgroup_max.call&.strip
          current = @cgroup_current.call&.strip
          return nil if max.nil? || current.nil?
          return nil if max == "max" # no cgroup limit set; host reading covers it

          limit = max.to_i
          used = current.to_i
          { limit:, available: [limit - used, 0].max }
        end

        def read_file(path)
          File.read(path)
        rescue SystemCallError
          nil
        end
      end
    end
  end
end

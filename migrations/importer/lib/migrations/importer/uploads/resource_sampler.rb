# frozen_string_literal: true

module Migrations
  module Importer
    module Uploads
      # Reads how busy the machine is right now, so the {AdaptiveController} can
      # decide whether adding workers is safe. Two independent signals:
      #
      #   * CPU busy fraction. Under a cgroup v2 CPU quota it comes from the
      #     cgroup's own `cpu.stat` usage against the quota, because the host-wide
      #     numbers of a big node say nothing about a small pod's share. Otherwise
      #     from `/proc/stat`, whose first line counts every process on the
      #     machine, so it includes image processing subprocesses and a local
      #     Postgres, not only our Ruby threads. Without procfs (non-Linux) it falls
      #     back to `Process.times`, which includes `cutime`/`cstime` (reaped
      #     children) spread over the interval times the usable CPU count.
      #   * Memory headroom. `MemAvailable` from `/proc/meminfo`, tightened by the
      #     cgroup v2 limit when the process runs under one — a container is usually
      #     capped well below the host's RAM. Returns nil when memory can't be read
      #     at all, and the controller then leaves the memory policy switched off
      #     rather than guessing.
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

        MICROSECONDS_PER_SECOND = 1_000_000

        def initialize(
          usable_cpus:,
          clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) },
          proc_stat: -> { read_file("/proc/stat") },
          meminfo: -> { read_file("/proc/meminfo") },
          cgroup_max: -> { read_file("/sys/fs/cgroup/memory.max") },
          cgroup_current: -> { read_file("/sys/fs/cgroup/memory.current") },
          cgroup_memory_stat: -> { read_file("/sys/fs/cgroup/memory.stat") },
          cgroup_cpu_max: -> { read_file("/sys/fs/cgroup/cpu.max") },
          cgroup_cpu_stat: -> { read_file("/sys/fs/cgroup/cpu.stat") },
          process_times: -> { Process.times }
        )
          @usable_cpus = usable_cpus
          @clock = clock
          @proc_stat = proc_stat
          @meminfo = meminfo
          @cgroup_max = cgroup_max
          @cgroup_current = cgroup_current
          @cgroup_memory_stat = cgroup_memory_stat
          @cgroup_cpu_max = cgroup_cpu_max
          @cgroup_cpu_stat = cgroup_cpu_stat
          @process_times = process_times

          # Prime the CPU baseline so the first `sample` measures a real delta over
          # the first interval instead of the whole process lifetime.
          @previous_cpu = cpu_snapshot
        end

        def sample
          fraction, bytes = memory_headroom
          Reading.new(cpu_busy:, memory_fraction: fraction, memory_bytes: bytes)
        end

        private

        # Busy fraction (0.0..1.0) over the interval since the last call.
        def cpu_busy
          snapshot = cpu_snapshot
          previous = @previous_cpu
          @previous_cpu = snapshot
          return 0.0 if snapshot.nil? || previous.nil?
          # Units differ per source, so a delta across a source switch means nothing.
          return 0.0 if snapshot[:source] != previous[:source]

          delta_total = snapshot[:total] - previous[:total]
          return 0.0 if delta_total <= 0

          delta_busy = snapshot[:busy] - previous[:busy]
          (delta_busy.to_f / delta_total).clamp(0.0, 1.0)
        end

        # `{ source:, busy:, total: }` in whatever unit the source uses — only the
        # ratio of two snapshots from the same source matters.
        def cpu_snapshot
          from_cgroup_cpu || from_proc_stat || from_process_times
        end

        # Usage against the quota, so the fraction is "of the CPU time the cgroup
        # may use", matching `usable_cpus`, which also follows the quota.
        def from_cgroup_cpu
          quota_cpus = cgroup_quota_cpus
          return nil if quota_cpus.nil?

          usage = @cgroup_cpu_stat.call&.[](/^usage_usec\s+(\d+)/, 1)
          return nil if usage.nil?

          {
            source: :cgroup,
            busy: usage.to_i,
            total: @clock.call * MICROSECONDS_PER_SECOND * quota_cpus,
          }
        end

        # `cpu.max` is "<quota> <period>" or "max <period>" when unlimited.
        def cgroup_quota_cpus
          quota, period = @cgroup_cpu_max.call.to_s.split
          return nil if quota.nil? || quota == "max" || period.to_i <= 0

          cpus = quota.to_f / period.to_i
          cpus > 0 ? cpus : nil
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
          { source: :proc_stat, busy: total - idle, total: }
        end

        # Wall time times the usable CPUs is the denominator, so the fraction is
        # "of all the cores we may use", matching the procfs reading.
        def from_process_times
          times = @process_times.call
          cpu_seconds = times.utime + times.stime + times.cutime + times.cstime
          { source: :process_times, busy: cpu_seconds, total: @clock.call * @usable_cpus }
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

        # `memory.current` includes page cache, which the kernel reclaims before
        # it OOM-kills anything; an IO-heavy run would look permanently out of
        # memory. Subtracting `inactive_file` gives the working set, the same
        # measure container runtimes use for eviction.
        def cgroup_headroom
          max = @cgroup_max.call&.strip
          current = @cgroup_current.call&.strip
          return nil if max.nil? || current.nil?
          return nil if max == "max" # no cgroup limit set; host reading covers it

          limit = max.to_i
          inactive_file = @cgroup_memory_stat.call&.[](/^inactive_file\s+(\d+)/, 1).to_i
          used = [current.to_i - inactive_file, 0].max
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

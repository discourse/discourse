# frozen_string_literal: true

module Migrations
  module Importer
    module Uploads
      # Decides how many upload workers should run, and keeps deciding while the
      # task runs. A background thread ticks every couple of seconds; each tick it
      # samples the machine, then nudges the {WorkerGate}'s target up or down.
      #
      # Why not a static worker count? The benchmarks showed the best count swings
      # from ~8 (local store, CPU-bound image cooking) to ~24 (an 8-core box
      # pushing to S3, where each worker parks on network latency) for the very
      # same code. And CPU% alone lies: the local-store image path tops out with
      # the box at ~27-47% CPU, because the ceiling is the single writer thread
      # plus GVL-serialized Ruby, not the cores. So throughput plateau detection is
      # the primary signal here and CPU is only a guard rail.
      #
      # Decision order each tick, strictest first:
      #   1. Memory. OOM is fatal, oscillation is not, so memory wins outright:
      #      near-empty halves the target (below the normal floor) and freezes
      #      increases; merely low blocks increases for the tick.
      #   2. CPU. Genuinely saturated (>95%) means back off a little; in-flight
      #      convert subprocesses lag the signal, so wait a couple of ticks after.
      #   3. Otherwise probe upward — but only while the work queue is actually
      #      backed up (more permits do nothing when the producer is the bottleneck)
      #      and only while the plateau guard says the last probes still paid off.
      class AdaptiveController
        # --- Tuning constants, all in one place. These are first guesses to be
        # retuned on real infra; the point of the design is that being a little off
        # self-corrects instead of locking in the wrong number. ---

        SEED_FACTOR = 1.5 # today's heuristic: usable_cpus * 1.5 * store_factor
        FLOOR = 2 # normal minimum; only a memory emergency goes below it
        AR_POOL_RESERVE = 8 # connections left for the writer + producer + slack
        CEILING_FACTOR_LOCAL = 4 # local store: CPU-bound, few workers needed
        CEILING_FACTOR_EXTERNAL = 16 # S3: workers park on PUT latency, so many help
        FD_BASELINE = 256 # file descriptors the process needs before any workers
        FD_PER_WORKER = 16 # rough per-worker fd budget (tempfiles, sockets, DB)

        MEMORY_EMERGENCY_FRACTION = 0.12
        MEMORY_EMERGENCY_BYTES = 1 * 1024**3 # 1 GB
        MEMORY_CAUTION_FRACTION = 0.25
        MEMORY_CAUTION_BYTES = 2 * 1024**3 # 2 GB
        INCREASE_FREEZE_TICKS = 5 # hold after an emergency, long enough to recover

        CPU_HIGH = 0.95
        CPU_HIGH_COOLDOWN_TICKS = 2
        CPU_FAST_INCREASE = 0.60 # below this the box is idle enough to jump
        INCREASE_STEP_FAST = 4
        INCREASE_STEP_SLOW = 1

        PLATEAU_GAIN = 0.05 # an increase must buy >5% throughput to count
        PLATEAU_LOW_GAIN_LIMIT = 2 # two weak probes in a row means we've plateaued
        PLATEAU_HOLD_SECONDS = 30 # wait this long after a plateau before probing again

        DEFAULT_INTERVAL = 2.0

        Plan = Data.define(:seed, :floor, :ceiling)

        # Works out the seed target and the hard bounds from the machine and the
        # store. Split out so it can be unit-tested without a live pipeline.
        def self.plan(usable_cpus:, store_external:, ar_pool_size:, fd_limit:)
          store_factor = store_external ? 2 : 1
          seed = (usable_cpus * SEED_FACTOR * store_factor).round

          store_ceiling =
            (store_external ? CEILING_FACTOR_EXTERNAL : CEILING_FACTOR_LOCAL) * usable_cpus
          fd_ceiling = [(fd_limit - FD_BASELINE) / FD_PER_WORKER, 1].max
          ceiling = [ar_pool_size - AR_POOL_RESERVE, store_ceiling, fd_ceiling].min
          ceiling = [ceiling, FLOOR].max

          Plan.new(seed: seed.clamp(FLOOR, ceiling), floor: FLOOR, ceiling:)
        end

        # @param gate [WorkerGate] the semaphore whose target this drives
        # @param sampler [ResourceSampler] the machine sampler (or any object with #sample)
        # @param step the reporter step handle, for {#report_concurrency}
        # @param ceiling [Integer] the hard upper bound on the target
        # @param work_available [#call] true while the work queue has items to hand out
        # @param completed_count [#call] a monotonically growing count of written items
        def initialize(
          gate:,
          sampler:,
          step:,
          ceiling:,
          work_available:,
          completed_count:,
          interval: DEFAULT_INTERVAL,
          clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
        )
          @gate = gate
          @sampler = sampler
          @step = step
          @ceiling = ceiling
          @work_available = work_available
          @completed_count = completed_count
          @interval = interval
          @clock = clock

          @increase_freeze_ticks = 0
          @cpu_cooldown_ticks = 0
          @low_gain_streak = 0
          @awaiting_probe = false
          @throughput_before_probe = 0.0
          @last_probe_step = 0
          @hold_until = 0.0

          now = @clock.call
          @last_sample_time = now
          @last_completed = @completed_count.call
        end

        def start
          @stop_mutex = Mutex.new
          @stop_condition = ConditionVariable.new
          @stopped = false
          @thread =
            Thread.new do
              Thread.current.name = "uploads-adaptive-controller"
              run_loop
            end
        end

        # Stop the controller thread and wait for it to finish. Idempotent.
        def stop
          return unless @thread

          @stop_mutex.synchronize do
            @stopped = true
            @stop_condition.broadcast
          end
          @thread.join
          @thread = nil
        end

        # One decision. Public so specs can drive ticks by hand with a fake clock
        # and sampler instead of waiting on the real thread.
        def tick
          now = @clock.call
          sample = @sampler.sample
          throughput = measure_throughput(now)

          count_down_timers
          resolve_probe(throughput) if @awaiting_probe

          return if handle_memory_emergency(sample)

          caution = memory_caution?(sample)
          return if handle_high_cpu(sample)

          maybe_increase(sample, throughput, now, caution:)
        end

        private

        def run_loop
          loop do
            @stop_mutex.synchronize { @stop_condition.wait(@stop_mutex, @interval) unless @stopped }
            break if stopped?
            tick
          end
        rescue StandardError
          # Tuning is best-effort: if a tick blows up, leave the target where it is
          # and let the pipeline finish rather than taking the run down with it.
        end

        def stopped?
          @stop_mutex.synchronize { @stopped }
        end

        def measure_throughput(now)
          completed = @completed_count.call
          elapsed = now - @last_sample_time
          rate = elapsed > 0 ? (completed - @last_completed) / elapsed : 0.0
          @last_completed = completed
          @last_sample_time = now
          rate
        end

        def count_down_timers
          @increase_freeze_ticks -= 1 if @increase_freeze_ticks > 0
          @cpu_cooldown_ticks -= 1 if @cpu_cooldown_ticks > 0
        end

        # Grade the probe from a couple of ticks ago. Two weak probes in a row and
        # we call it a plateau: undo the last step and stop probing for a while, so
        # we don't keep paying for workers that buy nothing.
        def resolve_probe(throughput)
          @awaiting_probe = false
          baseline = @throughput_before_probe
          gain = baseline > 0 ? (throughput - baseline) / baseline : 1.0

          if gain < PLATEAU_GAIN
            @low_gain_streak += 1
            if @low_gain_streak >= PLATEAU_LOW_GAIN_LIMIT
              set_target([@gate.target - @last_probe_step, FLOOR].max)
              @hold_until = @clock.call + PLATEAU_HOLD_SECONDS
              @low_gain_streak = 0
            end
          else
            @low_gain_streak = 0
          end
        end

        def handle_memory_emergency(sample)
          return false unless sample.memory_known?
          unless memory_below?(sample, MEMORY_EMERGENCY_FRACTION, MEMORY_EMERGENCY_BYTES)
            return false
          end

          # Below the normal floor on purpose — OOM beats every other concern.
          set_target([@gate.target / 2, 1].max)
          @increase_freeze_ticks = INCREASE_FREEZE_TICKS
          reset_probe_state
          true
        end

        def memory_caution?(sample)
          return false unless sample.memory_known?

          memory_below?(sample, MEMORY_CAUTION_FRACTION, MEMORY_CAUTION_BYTES)
        end

        # Pressure means available memory is below BOTH thresholds, i.e. below the
        # smaller of the two. The fraction guards small boxes (25% of 4 GB is the
        # binding limit there), the absolute bytes guard big ones — a 256 GB server
        # with dozens of GB free must not count as pressure just because that's
        # less than 25%.
        def memory_below?(sample, fraction, bytes)
          sample.memory_fraction < fraction && sample.memory_bytes < bytes
        end

        def handle_high_cpu(sample)
          return false if sample.cpu_busy <= CPU_HIGH

          set_target([@gate.target - [@gate.target / 8, 1].max, FLOOR].max)
          @cpu_cooldown_ticks = CPU_HIGH_COOLDOWN_TICKS
          reset_probe_state
          true
        end

        def maybe_increase(sample, throughput, now, caution:)
          return if caution
          return if @increase_freeze_ticks > 0
          return if @cpu_cooldown_ticks > 0
          return if @awaiting_probe # still grading the previous probe
          return if now < @hold_until
          return unless @work_available.call # producer-bound: more permits do nothing
          return if @gate.target >= @ceiling

          step = sample.cpu_busy < CPU_FAST_INCREASE ? INCREASE_STEP_FAST : INCREASE_STEP_SLOW
          new_target = [@gate.target + step, @ceiling].min
          step = new_target - @gate.target
          return if step <= 0

          @throughput_before_probe = throughput
          @last_probe_step = step
          @awaiting_probe = true
          set_target(new_target)
        end

        def reset_probe_state
          @awaiting_probe = false
          @low_gain_streak = 0
        end

        def set_target(value)
          clamped = value.clamp(1, @ceiling)
          return if clamped == @gate.target

          @gate.target = clamped
          @step.report_concurrency(clamped)
        end
      end
    end
  end
end

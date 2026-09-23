# frozen_string_literal: true

module Migrations
  module Importer
    module Uploads
      # Decides how many upload workers should run, and keeps deciding while the
      # task runs. A background thread ticks every couple of seconds. On each tick
      # it samples the machine and moves the {WorkerGate}'s target up or down.
      #
      # A fixed worker count does not fit every run. With a local store, image
      # processing uses the CPU and few workers are enough. With S3, each worker
      # mostly waits for the network, so many more workers help. CPU usage alone
      # is not a good signal either: with a local store, throughput can stop
      # growing long before the CPU is busy, because the single writer thread and
      # the GVL limit it. So the main signal is whether more workers still give
      # more throughput. CPU usage is only used to back off when the CPU is
      # saturated.
      #
      # Decision order each tick, strictest first:
      #   1. Memory. Running out of memory ends the run, so memory comes first.
      #      When almost no memory is left, the target is halved (even below the
      #      normal floor) and increases are paused for a few ticks. When memory
      #      is only low, there is no increase on this tick.
      #   2. CPU. When the CPU is saturated (>95%), the target goes down a little.
      #      Image processing that is still running shows up in the signal late,
      #      so the controller waits a couple of ticks after that.
      #   3. Otherwise try a higher target, but only while the work queue has
      #      items waiting (more workers do not help when the producer is the
      #      bottleneck) and only while the last increases still raised the
      #      throughput.
      #
      # Throughput is measured over PROBE_GRADE_TICKS ticks at one unchanged
      # target. Single ticks are too noisy to compare, and a window that includes
      # a target change would mix two worker counts into one number.
      class AdaptiveController
        # Tuning constants. The controller corrects a target that is a little
        # off, so these values do not need to be exact.

        SEED_FACTOR = 1.5 # seed: usable_cpus * SEED_FACTOR, doubled for an external store
        FLOOR = 2 # normal minimum; only a memory emergency goes below it
        AR_POOL_RESERVE = 8 # connections left for the writer + producer + slack
        CEILING_FACTOR_LOCAL = 4 # local store: CPU-bound, few workers needed
        CEILING_FACTOR_EXTERNAL = 16 # S3: workers mostly wait for the network, so many help
        FD_BASELINE = 256 # file descriptors the process needs before any workers
        FD_PER_WORKER = 16 # rough per-worker fd budget (tempfiles, sockets, DB)

        MEMORY_EMERGENCY_FRACTION = 0.12
        MEMORY_EMERGENCY_BYTES = 1 * 1024**3 # 1 GB
        MEMORY_CAUTION_FRACTION = 0.25
        MEMORY_CAUTION_BYTES = 2 * 1024**3 # 2 GB
        INCREASE_FREEZE_TICKS = 5 # hold after an emergency, long enough to recover

        CPU_HIGH = 0.95
        CPU_HIGH_COOLDOWN_TICKS = 2
        CPU_FAST_INCREASE = 0.60 # below this the CPU is idle enough for a big step
        INCREASE_STEP_FAST = 4
        INCREASE_STEP_SLOW = 1

        PLATEAU_GAIN = 0.05 # an increase must raise throughput by >5% to count
        PLATEAU_LOW_GAIN_LIMIT = 2 # weak probes in a row that mean throughput stopped growing
        PLATEAU_HOLD_SECONDS = 30 # wait this long after a plateau before probing again
        PROBE_GRADE_TICKS = 3 # ticks per throughput window, for baselines and grades

        DEFAULT_INTERVAL = 2.0

        Plan = Data.define(:seed, :ceiling)

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

          Plan.new(seed: seed.clamp(FLOOR, ceiling), ceiling:)
        end

        # @param gate [WorkerGate] the semaphore whose target this drives
        # @param sampler [ResourceSampler] the machine sampler (or any object with #sample)
        # @param step the reporter step handle, for {#report_concurrency} and {#notice}
        # @param ceiling [Integer] the hard upper bound on the target
        # @param work_available [#call] true while the work queue has items to hand out
        # @param completed_count [#call] a monotonically growing count of finished items
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
          @target_before_streak = nil
          @hold_until = 0.0
          @tick_error_reported = false

          restart_window(@clock.call)
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
          @window_ticks += 1

          count_down_timers
          resolve_probe(now) if @awaiting_probe && window_complete?

          return if handle_memory_emergency(sample, now)

          caution = memory_caution?(sample)
          return if handle_high_cpu(sample, now)

          maybe_increase(sample, now, caution:)
        end

        private

        def run_loop
          loop do
            @stop_mutex.synchronize { @stop_condition.wait(@stop_mutex, @interval) unless @stopped }
            break if stopped?

            safe_tick
          end
        end

        # A failing tick must not stop the run. It leaves the target where it is,
        # and the next tick tries again. The error is reported only once, so it is
        # visible without a new notice on every tick.
        def safe_tick
          tick
        rescue StandardError => e
          return if @tick_error_reported

          @tick_error_reported = true
          @step.notice(
            I18n.t(
              "importer.uploads.adaptive_controller_failed",
              error: "#{e.class}: #{e.message}",
            ),
          )
        end

        def stopped?
          @stop_mutex.synchronize { @stopped }
        end

        def restart_window(now)
          @window_started_at = now
          @window_start_completed = @completed_count.call
          @window_ticks = 0
        end

        def window_complete?
          @window_ticks >= PROBE_GRADE_TICKS
        end

        def window_throughput(now)
          elapsed = now - @window_started_at
          return 0.0 if elapsed <= 0

          (@completed_count.call - @window_start_completed) / elapsed
        end

        def count_down_timers
          @increase_freeze_ticks -= 1 if @increase_freeze_ticks > 0
          @cpu_cooldown_ticks -= 1 if @cpu_cooldown_ticks > 0
        end

        # Compares the probe with the window before it. After two weak probes in a
        # row, the throughput has stopped growing: go back to the target from
        # before the weak probes and stop probing for PLATEAU_HOLD_SECONDS, so the
        # run does not keep workers that add nothing. Going back only one step
        # would keep the earlier weak step, and the target would grow by one step
        # in every such cycle.
        #
        # A zero baseline (nothing finished in the window before the probe) says
        # nothing about whether the probe helped, so it neither extends nor breaks
        # the streak.
        def resolve_probe(now)
          @awaiting_probe = false
          baseline = @throughput_before_probe
          return if baseline <= 0

          gain = (window_throughput(now) - baseline) / baseline
          if gain >= PLATEAU_GAIN
            @low_gain_streak = 0
            return
          end

          @low_gain_streak += 1
          return if @low_gain_streak < PLATEAU_LOW_GAIN_LIMIT

          set_target(@target_before_streak, now)
          @hold_until = now + PLATEAU_HOLD_SECONDS
          @low_gain_streak = 0
        end

        def handle_memory_emergency(sample, now)
          return false unless sample.memory_known?
          unless memory_below?(sample, MEMORY_EMERGENCY_FRACTION, MEMORY_EMERGENCY_BYTES)
            return false
          end

          # Below the normal floor on purpose: running out of memory is worse than
          # running with too few workers.
          set_target([@gate.target / 2, 1].max, now)
          @increase_freeze_ticks = INCREASE_FREEZE_TICKS
          reset_probe_state
          true
        end

        def memory_caution?(sample)
          return false unless sample.memory_known?

          memory_below?(sample, MEMORY_CAUTION_FRACTION, MEMORY_CAUTION_BYTES)
        end

        # Memory is low only when the available memory is below BOTH thresholds.
        # On a small machine the fraction decides (25% of 4 GB). On a big machine
        # the byte limit decides: a 256 GB server with dozens of GB free is not
        # low on memory just because that is less than 25%.
        def memory_below?(sample, fraction, bytes)
          sample.memory_fraction < fraction && sample.memory_bytes < bytes
        end

        # A back-off never raises the target: a memory emergency may have pushed it
        # below FLOOR, and clamping up to FLOOR would grow it.
        def handle_high_cpu(sample, now)
          return false if sample.cpu_busy <= CPU_HIGH

          current = @gate.target
          backed_off = [current - [current / 8, 1].max, FLOOR].max
          set_target([current, backed_off].min, now)
          @cpu_cooldown_ticks = CPU_HIGH_COOLDOWN_TICKS
          reset_probe_state
          true
        end

        def maybe_increase(sample, now, caution:)
          return if caution
          return if @increase_freeze_ticks > 0
          return if @cpu_cooldown_ticks > 0
          return if @awaiting_probe # still grading the previous probe
          return unless window_complete? # no baseline at the current target yet
          return if now < @hold_until
          return unless @work_available.call # producer-bound: more permits do nothing

          current = @gate.target
          return if current >= @ceiling

          step = sample.cpu_busy < CPU_FAST_INCREASE ? INCREASE_STEP_FAST : INCREASE_STEP_SLOW
          @throughput_before_probe = window_throughput(now)
          @target_before_streak = current if @low_gain_streak == 0
          @awaiting_probe = true
          set_target([current + step, @ceiling].min, now)
        end

        def reset_probe_state
          @awaiting_probe = false
          @low_gain_streak = 0
        end

        # Every change starts a fresh throughput window, so a baseline or a grade
        # only ever covers ticks at a single target.
        def set_target(value, now)
          clamped = value.clamp(1, @ceiling)
          return if clamped == @gate.target

          @gate.target = clamped
          restart_window(now)
          @step.report_concurrency(clamped)
        end
      end
    end
  end
end

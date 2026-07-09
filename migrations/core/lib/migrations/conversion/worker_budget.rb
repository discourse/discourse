# frozen_string_literal: true

require "etc"
require "concurrent/utility/processor_counter" # just the CPU counter, not all of concurrent-ruby

module Migrations
  module Conversion
    # Works out how many worker forks a run may use: the CPUs it can actually run
    # on, minus a core kept for the parent process and the background shard merges.
    #
    # "CPUs it can run on" is not just the host core count. In a container the run
    # is usually limited by a CFS quota (`docker --cpus`, k8s `limits.cpu`), which
    # `Etc.nprocessors` ignores. So we take the tighter of two numbers:
    #
    #   * `Etc.nprocessors` — respects CPU affinity (`taskset`, cpuset)
    #   * `Concurrent.available_processor_count` — respects the CFS quota
    #
    # Their minimum is the effective budget, so a 4-CPU pod on a 64-core node uses
    # 4, not 64.
    module WorkerBudget
      # Cores held back for the scheduler/coordinator threads (mostly idle, waiting
      # on IO) and the single consolidator merge thread. This is fixed, not scaled
      # with core count: the background work is about one busy thread, so one core
      # is enough on any machine — reserving more would just waste worker slots.
      RESERVED_CORES = 1

      def self.available(reserved: RESERVED_CORES)
        [usable_cpus - reserved, 1].max
      end

      # The CFS quota can be fractional (e.g. `--cpus=1.5`), so floor it; never
      # report fewer than one usable CPU.
      def self.usable_cpus
        [[Etc.nprocessors, Concurrent.available_processor_count.floor].min, 1].max
      end
    end
  end
end

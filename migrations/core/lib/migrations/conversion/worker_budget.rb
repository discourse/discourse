# frozen_string_literal: true

module Migrations
  module Conversion
    # Works out how many worker forks a run may use: the CPUs it can actually run
    # on (see {Migrations::SystemInfo.usable_cpus}), minus a core kept for the
    # parent process and the background shard merges.
    module WorkerBudget
      # Cores held back for the scheduler/coordinator threads (mostly idle, waiting
      # on IO) and the single consolidator merge thread. This is fixed, not scaled
      # with core count: the background work is about one busy thread, so one core
      # is enough on any machine — reserving more would just waste worker slots.
      RESERVED_CORES = 1

      def self.available(reserved: RESERVED_CORES)
        [SystemInfo.usable_cpus - reserved, 1].max
      end
    end
  end
end

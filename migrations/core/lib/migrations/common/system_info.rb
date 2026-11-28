# frozen_string_literal: true

require "etc"
require "concurrent/utility/processor_counter" # just the CPU counter, not all of concurrent-ruby

module Migrations
  # Small, generic facts about the machine the run is on. Kept out of any one
  # tool's namespace because both the fork-based converter and the threaded
  # uploads pipeline need the same CPU budget.
  module SystemInfo
    # The number of CPUs the process may actually run on. This is not just the
    # host core count: in a container the run is usually limited by a CFS quota
    # (`docker --cpus`, k8s `limits.cpu`), which `Etc.nprocessors` ignores. So we
    # take the tighter of two numbers:
    #
    #   * `Etc.nprocessors` — respects CPU affinity (`taskset`, cpuset)
    #   * `Concurrent.available_processor_count` — respects the CFS quota
    #
    # Their minimum is the effective budget, so a 4-CPU pod on a 64-core node uses
    # 4, not 64. The quota can be fractional (e.g. `--cpus=1.5`), so floor it, and
    # never report fewer than one usable CPU.
    def self.usable_cpus
      [[Etc.nprocessors, Concurrent.available_processor_count.floor].min, 1].max
    end
  end
end

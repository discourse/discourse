# frozen_string_literal: true

module Migrations
  module Conversion
    # Wraps a processor's `setup` so it can't create IntermediateDB records:
    # for the duration of the call the IntermediateDB connection is replaced
    # by one that raises on insert. Without the guard such writes would be
    # silently discarded in parallel mode (each worker's `OfflineConnection`
    # is cleared before the first item) but persisted in serial mode — the
    # guard makes both modes fail loudly and identically, with a backtrace
    # pointing at the offending write.
    module SetupGuard
      class SetupError < StandardError
      end

      class NoWriteConnection
        def insert(*)
          raise SetupError,
                "Processors must not create IntermediateDB records during `setup`. " \
                  "Build per-worker state in `setup` and create records in `process` instead."
        end
      end

      def self.run(processor)
        Database::IntermediateDB.with_connection(NoWriteConnection.new) { processor.setup }
      end
    end
  end
end

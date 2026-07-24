# frozen_string_literal: true

module Migrations
  module Conversion
    # Wraps a processor's `setup` so a write to the IntermediateDB raises instead
    # of slipping through: `setup` builds per-worker state, not rows, so a stray
    # write there would land outside the per-item error handling.
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

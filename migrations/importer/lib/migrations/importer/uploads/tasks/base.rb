# frozen_string_literal: true

module Migrations
  module Importer
    module Uploads
      module Tasks
        # Shared state and helpers for the upload tasks. The threading lives in
        # {Pipeline}; a task only describes the work. Each task is a hook object
        # the pipeline drives (see {Pipeline} for the full interface).
        class Base
          include StoreProbe

          attr_reader :files_db, :intermediate_db, :settings, :discourse_store
          attr_writer :reporter

          def initialize(databases, settings)
            @files_db = databases[:files_db]
            @intermediate_db = databases[:intermediate_db]
            @settings = settings
            @discourse_store = Discourse.store
          end

          # --- Pipeline hooks with sensible defaults; tasks override as needed. ---

          def before_run
          end

          # Commit whatever the writer left in the open transaction, so an
          # interrupted run stays resumable from what already reached disk.
          def after_run
            files_db.commit_transaction
          end

          def build_worker_resource
            nil
          end

          # Whether uploads land on an external store (S3). The pipeline's worker
          # bounds lean on this: an external store's uploads spend most of their
          # time parked on network latency, so many more workers pay off than on a
          # local, CPU-bound store.
          def store_external?
            discourse_store.external?
          end

          protected

          attr_reader :reporter

          def load_existing_ids(db, sql)
            set = Set.new
            db.query(sql) { |row| set << row[:id] }
            set
          end
        end
      end
    end
  end
end

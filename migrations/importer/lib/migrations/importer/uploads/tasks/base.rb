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

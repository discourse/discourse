# frozen_string_literal: true

require "etc"

module Migrations
  module Importer
    module Uploads
      module Tasks
        # Shared state and helpers for the upload tasks. The threading lives in
        # {Pipeline}; a task only describes the work. Each task is a hook object
        # the pipeline drives (see {Pipeline} for the full interface).
        class Base
          DEFAULT_THREAD_FACTOR = 1.5

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

          # Same static formula as before the rework: cores, scaled by the
          # configured factor, doubled for an external store (its uploads spend
          # most of their time waiting on the network).
          def worker_count
            base = Etc.nprocessors
            factor = settings.fetch(:thread_count_factor, DEFAULT_THREAD_FACTOR)
            store_factor = discourse_store.external? ? 2 : 1

            (base * factor * store_factor).to_i
          end

          protected

          attr_reader :reporter

          def load_existing_ids(db, sql)
            set = Set.new
            db.query(sql) { |row| set << row[:id] }
            set
          end

          def add_multisite_prefix(path)
            return path if !Rails.configuration.multisite

            File.join("uploads", RailsMultisite::ConnectionManagement.current_db, path)
          end

          def file_exists?(path)
            if discourse_store.external?
              discourse_store.object_from_path(path).exists?
            else
              File.exist?(File.join(discourse_store.public_dir, path))
            end
          end
        end
      end
    end
  end
end

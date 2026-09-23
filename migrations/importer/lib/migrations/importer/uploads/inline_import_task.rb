# frozen_string_literal: true

module Migrations
  module Importer
    module Uploads
      # The pipeline task behind inline upload mode: when `disco import` runs
      # without a files DB, this uploads the source files straight into the live
      # target site and records where each one landed in the mappings DB. It shares
      # {UploadCreationService} with `disco upload`; the only differences are that
      # each upload is owned by its mapped importer user, and that the results go
      # to `mapped.ids` + `mapped.upload_markdown` instead of the files DB.
      #
      # The IntermediateDB connection (with `mapped` attached) is not
      # thread-safe. The work list is loaded before the pipeline starts, and after
      # that only the pipeline's single writer thread ({#write}) uses the
      # connection, never the workers.
      class InlineImportTask
        include StoreProbe

        INSERT_MAPPED_ID_SQL = <<~SQL
          INSERT INTO mapped.ids (original_id, type, discourse_id)
          VALUES (?, ?, ?)
        SQL

        INSERT_MARKDOWN_SQL = <<~SQL
          INSERT INTO mapped.upload_markdown (original_id, markdown)
          VALUES (?, ?)
        SQL

        attr_writer :reporter

        # @param work_list [Array<Hash>] materialized `upload_sources` rows to upload
        # @param intermediate_db the step's connection; only {#write} may touch it
        # @param upload_service [UploadCreationService]
        def initialize(work_list:, intermediate_db:, upload_service:)
          @work_list = work_list
          @intermediate_db = intermediate_db
          @upload_service = upload_service
        end

        def title
          Steps::Uploads.title
        end

        def before_run
        end

        def after_run
          @intermediate_db.commit_transaction
        end

        def max_count
          @work_list.size
        end

        def discourse_store
          @upload_service.discourse_store
        end

        def build_worker_resource
          nil
        end

        # The pipeline also passes `emit_result:` (for rows a task resolves up
        # front); inline mode resolves nothing early, so it is ignored.
        def produce(emit_work:, **)
          @work_list.each { |row| emit_work.call(row) }
        end

        # Runs on a worker thread, so it must not use the IntermediateDB. It
        # returns a plain hash and not the `Upload`, so no AR object is passed to
        # the writer thread.
        def process(row, _resource)
          result = @upload_service.create(row, user_id: row[:resolved_user_id])
          return nil if result.nil?

          {
            original_id: row[:id],
            filename: row[:filename],
            status: result.status,
            discourse_id: result.upload&.id,
            markdown: result.markdown,
            skip_details: result.skip_details,
            download: result.download,
          }
        end

        # Runs on the single writer thread, the only one allowed to touch the
        # IntermediateDB connection.
        def write(entry)
          case entry[:status]
          when UploadCreationService::Status::OK
            @intermediate_db.insert(
              INSERT_MAPPED_ID_SQL,
              [entry[:original_id], MappingType::UPLOADS, entry[:discourse_id]],
            )
            @intermediate_db.insert(INSERT_MARKDOWN_SQL, [entry[:original_id], entry[:markdown]])
            :ok
          when UploadCreationService::Status::SKIPPED
            # Left unmapped on purpose, so later steps treat references to it
            # as unresolved.
            @reporter.notice(
              I18n.t(
                "importer.uploads.file_not_found",
                id: entry[:original_id],
                filename: entry[:filename],
              ),
            )
            :skip
          else
            @reporter.notice(
              I18n.t(
                "importer.uploads.upload_failed",
                id: entry[:original_id],
                error: entry[:skip_details],
              ),
            )
            :error
          end
        rescue StandardError => e
          @reporter.notice(
            I18n.t("importer.uploads.insert_failed", id: entry[:original_id], error: e.message),
          )
          :error
        end
      end
    end
  end
end

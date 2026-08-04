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
      # CRITICAL: the IntermediateDB connection (with `mapped` attached) is not
      # thread-safe. The work list is materialized before the pipeline starts, and
      # from then on the connection is touched only from the pipeline's single
      # writer thread ({#write}) — never from the workers.
      class InlineImportTask
        Status = Database::FilesDB::Enums::UploadResultStatus

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
        # @param downloads_store [Hash] in-memory filename cache the downloader reads
        def initialize(work_list:, intermediate_db:, upload_service:, downloads_store:)
          @work_list = work_list
          @intermediate_db = intermediate_db
          @upload_service = upload_service
          @downloads_store = downloads_store
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

        def store_external?
          Discourse.store.external?
        end

        def build_worker_resource
          nil
        end

        # The pipeline also passes `emit_result:` (for rows a task resolves up
        # front); inline mode resolves nothing early, so it is ignored.
        def produce(emit_work:, **)
          @work_list.each { |row| emit_work.call(row) }
        end

        # Runs on a worker thread — no IntermediateDB access. Shapes a plain hash
        # (never the live `Upload` object) so nothing AR-backed crosses to the
        # writer thread.
        def process(row, _resource)
          result = @upload_service.create(row, user_id: row[:resolved_user_id])
          return nil if result.nil?

          {
            original_id: row[:id],
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
          cache_download(entry[:download]) if entry[:download]

          case entry[:status]
          when Status::OK
            @intermediate_db.insert(
              INSERT_MAPPED_ID_SQL,
              [entry[:original_id], MappingType::UPLOADS, entry[:discourse_id]],
            )
            @intermediate_db.insert(INSERT_MARKDOWN_SQL, [entry[:original_id], entry[:markdown]])
            :ok
          when Status::SKIPPED
            # Left unmapped on purpose: the source id later surfaces as an
            # unresolved embed through the existing downstream mechanism.
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
        end

        private

        def cache_download(record)
          @downloads_store[record[:id]] = record[:original_filename]
        end
      end
    end
  end
end

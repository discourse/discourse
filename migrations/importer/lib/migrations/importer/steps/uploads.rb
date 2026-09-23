# frozen_string_literal: true

module Migrations
  module Importer
    module Steps
      class Uploads < CopyStep
        depends_on :users
        store_mapped_ids true

        # sha1 => id of an upload that already exists on the target site. Secure
        # uploads use a random sha1, so this identifies the same upload without
        # deduplicating different secure uploads that contain the same file.
        requires_mapping :existing_sha1s, "SELECT sha1, id FROM uploads"

        column_names %i[
                       user_id
                       original_filename
                       filesize
                       width
                       height
                       url
                       created_at
                       updated_at
                       sha1
                       origin
                       retain_hours
                       extension
                       thumbnail_width
                       thumbnail_height
                       etag
                       secure
                       access_control_post_id
                       original_sha1
                       animated
                       verification_status
                       security_last_changed_at
                       security_last_changed_reason
                       dominant_color
                     ]

        total_rows_query <<~SQL, MappingType::UPLOADS
          SELECT COUNT(*)
          FROM files.upload_results ur
               JOIN files.uploads u ON u.id = ur.upload_id
               LEFT JOIN mapped.ids mup ON ur.id = mup.original_id AND mup.type = ?1
          WHERE mup.original_id IS NULL
        SQL

        rows_query <<~SQL, MappingType::USERS, MappingType::UPLOADS, Discourse::SYSTEM_USER_ID
          SELECT ur.id                          AS original_id,
                 u.*,
                 COALESCE(mu.discourse_id, ?3)  AS user_id
          FROM files.upload_results ur
               JOIN files.uploads u ON u.id = ur.upload_id
               JOIN upload_sources us ON us.id = ur.id
               LEFT JOIN mapped.ids mu ON us.user_id = mu.original_id AND mu.type = ?1
               LEFT JOIN mapped.ids mup ON ur.id = mup.original_id AND mup.type = ?2
          WHERE mup.original_id IS NULL
          ORDER BY u.id
        SQL

        # A files DB means `disco upload` already created the uploads, so this
        # step only copies them (`super`). Without a files DB, the step creates
        # the uploads itself, directly on the target site. That is meant for
        # small migrations that skip the separate `disco upload` run.
        def execute
          if files_db_attached?
            super
          else
            InlineImport.new(self).run
          end
        end

        # Uploads the `upload_sources` that no upload run produced, using the same
        # {Importer::Uploads::UploadCreationService} `disco upload` uses. Each
        # created upload is recorded in the mappings DB: its id in `mapped.ids`,
        # and its Markdown in `mapped.upload_markdown` for later steps that need
        # to reference the upload.
        class InlineImport
          def initialize(step)
            @step = step
            @intermediate_db = step.intermediate_db
            @reporter = step.reporter
            @settings = step.config[:uploads] || {}
          end

          def run
            work_list =
              Importer::Uploads::InlineWorkList.rows(
                @intermediate_db,
                system_user_id: Discourse::SYSTEM_USER_ID,
              )
            return if work_list.empty?

            if @settings[:root_paths].blank? &&
                 Importer::Uploads::InlineWorkList.needs_root_paths?(work_list)
              raise_unconfigured
            end

            # Must run before the pipeline reads the pool size for its worker limit.
            Importer::Uploads::DatabasePool.configure!

            pipeline =
              Importer::Uploads::Pipeline.new(
                task: build_task(work_list),
                reporter: ExistingStepReporter.new(@reporter),
              )
            pipeline.run

            raise Interrupt if pipeline.interrupted?
          end

          private

          def build_task(work_list)
            service =
              Importer::Uploads::UploadCreationService.build(
                root_paths: @settings[:root_paths],
                path_replacements: @settings[:path_replacements],
                cache_path: @settings[:download_cache_path],
                # Inline mode does not store the original filenames of downloads,
                # so a new run downloads every URL again, even when the file is
                # still in the cache.
                downloads: {
                },
                discourse_store: Discourse.store,
              )

            Importer::Uploads::InlineImportTask.new(
              work_list:,
              intermediate_db: @intermediate_db,
              upload_service: service,
            )
          end

          def raise_unconfigured
            raise I18n.t("importer.uploads.inline_not_configured")
          end
        end

        # The pipeline starts its own step through a reporter, but inline mode
        # already runs inside the executor's uploads step. This object is both
        # the reporter and the step for the pipeline, and passes everything on
        # to the existing step, so progress and notices show up there. The
        # executor finishes that step itself, so `finish` does nothing.
        class ExistingStepReporter
          def initialize(step_handle)
            @step_handle = step_handle
          end

          def start_step(_title)
            self
          end

          def notice(message)
            @step_handle.notice(message)
          end

          def report_concurrency(count)
            @step_handle.report_concurrency(count)
          end

          def with_progress(max_progress:, &block)
            @step_handle.with_progress(max_progress:, &block)
          end

          def finish(outcome: nil)
          end
        end

        # Used by {InlineImport}.
        def intermediate_db
          @intermediate_db
        end

        def config
          @config
        end

        private

        def setup
          # files.uploads.id => the Discourse upload id it ended up as. Files are
          # deduplicated by sha1 when they are uploaded, so several source ids can
          # point at the same FilesDB upload.
          @files_db_upload_ids = {}
        end

        def transform_row(row)
          files_db_upload_id = row.delete(:id)
          sha1 = row[:sha1]

          # An earlier source file already used this FilesDB upload. Map this
          # source id to the Discourse upload we created for it and skip the
          # copy.
          if (discourse_id = @files_db_upload_ids[files_db_upload_id])
            row[:id] = discourse_id
            return nil
          end

          # The upload already exists on the target site. Reuse it. We only
          # match on a real sha1 because it is nullable and NULLs are not equal.
          if sha1 && (discourse_id = @existing_sha1s[sha1])
            @files_db_upload_ids[files_db_upload_id] = discourse_id
            row[:id] = discourse_id
            return nil
          end

          transformed = super
          discourse_id = transformed[:id]
          @files_db_upload_ids[files_db_upload_id] = discourse_id
          @existing_sha1s[sha1] = discourse_id if sha1
          transformed
        end
      end
    end
  end
end

# frozen_string_literal: true

module Migrations
  module Importer
    module Steps
      class Uploads < CopyStep
        depends_on :users
        store_mapped_ids true

        # sha1 => id of an upload that already exists on the target site, so we
        # can reuse it instead of copying the same file again.
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
                 u.id                           AS staging_id,
                 COALESCE(mu.discourse_id, ?3)  AS user_id,
                 u.original_filename,
                 u.filesize,
                 u.width,
                 u.height,
                 u.url,
                 u.created_at,
                 u.sha1,
                 u.origin,
                 u.extension,
                 u.thumbnail_width,
                 u.thumbnail_height,
                 u.etag,
                 u.secure,
                 u.original_sha1,
                 u.animated,
                 u.verification_status,
                 u.security_last_changed_at,
                 u.security_last_changed_reason,
                 u.dominant_color
          FROM files.upload_results ur
               JOIN files.uploads u ON u.id = ur.upload_id
               JOIN upload_sources us ON us.id = ur.id
               LEFT JOIN mapped.ids mu ON us.user_id = mu.original_id AND mu.type = ?1
               LEFT JOIN mapped.ids mup ON ur.id = mup.original_id AND mup.type = ?2
          WHERE mup.original_id IS NULL
          ORDER BY u.id
        SQL

        # A files DB means `disco upload` already created the uploads and this is
        # a plain column copy (`super`). Without one — small migrations that skip
        # the separate upload run — we upload the source files inline, straight
        # into the live target site, instead of skipping.
        def execute
          if files_db_attached?
            super
          else
            InlineImport.new(self).run
          end
        end

        # Uploads the `upload_sources` that no upload run produced, using the same
        # {Uploads::UploadCreationService} `disco upload` uses. It records where
        # each file landed in the mappings DB: `mapped.ids` for id resolution and
        # `mapped.upload_markdown` for the posts placeholder resolver (which reads
        # `files.upload_results.markdown` when a files DB is attached, and this
        # table otherwise).
        class InlineImport
          def initialize(step)
            @step = step
            @intermediate_db = step.intermediate_db
            @reporter = step.reporter
            @settings = step.config[:uploads] || {}
          end

          def run
            return if Uploads::InlineWorkList.pending_count(@intermediate_db) == 0
            raise_unconfigured if @settings[:root_paths].blank?

            # `clean_up_uploads` would sweep these freshly created uploads before
            # the later post steps attach them. Everything else about uploads
            # (extensions, size limits, S3 credentials) is already real on the live
            # target site, so we leave it alone.
            SiteSetting.clean_up_uploads = false

            pipeline = Uploads::Pipeline.new(task: build_task, reporter: reuse_step_reporter)
            pipeline.run

            raise Interrupt if pipeline.interrupted?
          end

          private

          def build_task
            downloads_store = {}
            work_list =
              Uploads::InlineWorkList.rows(
                @intermediate_db,
                system_user_id: Discourse::SYSTEM_USER_ID,
              )

            service =
              Uploads::UploadCreationService.new(
                locator:
                  Uploads::SourceFileLocator.new(
                    root_paths: @settings[:root_paths],
                    path_replacements: @settings[:path_replacements] || [],
                  ),
                downloader:
                  Uploads::FileDownloader.new(
                    cache_path: download_cache_path,
                    filename_store: downloads_store,
                  ),
                discourse_store: Discourse.store,
                retry_policy: Uploads::UploadCreationService.default_retry_policy,
              )

            Uploads::InlineImportTask.new(
              work_list:,
              intermediate_db: @intermediate_db,
              upload_service: service,
              downloads_store:,
            )
          end

          # Resolved up front (defaults to a `downloads` directory next to the
          # IntermediateDB), so we only have to make sure it exists here.
          def download_cache_path
            path = @settings[:download_cache_path]
            FileUtils.mkdir_p(path)
            path
          end

          # The pipeline drives its own step through a reporter, but here we are
          # already inside the executor's uploads step. This hands the pipeline the
          # existing step handle so its progress and notices land on that row; the
          # executor still owns the final `finish`, so we swallow the pipeline's.
          def reuse_step_reporter
            ReuseStepReporter.new(@reporter)
          end

          def raise_unconfigured
            raise I18n.t("importer.uploads.inline_not_configured")
          end
        end

        # See {InlineImport#reuse_step_reporter}.
        class ReuseStepReporter
          def initialize(step_handle)
            @step_handle = PipelineStepHandle.new(step_handle)
          end

          def start_step(_title)
            @step_handle
          end
        end

        class PipelineStepHandle
          def initialize(step_handle)
            @step_handle = step_handle
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

          # No-op: the executor finishes the step in its own `ensure`.
          def finish(outcome: nil)
          end
        end

        # Inline mode reaches these off the step; the files-DB copy path does not.
        def intermediate_db
          @intermediate_db
        end

        def config
          @config
        end

        private

        def setup
          # staging upload id (files.uploads.id) => the Discourse upload id it
          # ended up as. Files are deduplicated by sha1 when they are uploaded,
          # so several source ids can point at the same staging upload.
          @staging_upload_ids = {}
        end

        def transform_row(row)
          staging_id = row.delete(:staging_id)
          sha1 = row[:sha1]

          # An earlier source file already used this staging upload. Map this
          # source id to the Discourse upload we created for it and skip the
          # copy. Without this the mapping was lost and later references to the
          # deduplicated source ids resolved to NULL.
          if (discourse_id = @staging_upload_ids[staging_id])
            row[:id] = discourse_id
            return nil
          end

          # The same file already exists on the target site. Reuse it. We only
          # match on a real sha1 because it is nullable and NULLs are not equal.
          if sha1 && (discourse_id = @existing_sha1s[sha1])
            @staging_upload_ids[staging_id] = discourse_id
            row[:id] = discourse_id
            return nil
          end

          transformed = super
          discourse_id = transformed[:id]
          @staging_upload_ids[staging_id] = discourse_id
          @existing_sha1s[sha1] = discourse_id if sha1
          transformed
        end
      end
    end
  end
end

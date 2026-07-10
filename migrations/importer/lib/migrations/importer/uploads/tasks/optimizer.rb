# frozen_string_literal: true

module Migrations
  module Importer
    module Uploads
      module Tasks
        # Precomputes OptimizedImages for the uploads that need them (post images
        # and avatars). Each worker rebakes against a throwaway post; only
        # {#write} records the results.
        class Optimizer < Base
          OPTIMIZED_IMAGE_COLUMNS = %i[
            id
            created_at
            etag
            extension
            filesize
            height
            sha1
            upload_id
            url
            version
            width
          ].freeze

          def title
            "Creating optimized images"
          end

          def max_count
            @max_count
          end

          def before_run
            # Let several threads optimize at once.
            OptimizedImage.lock_per_machine = false
            # OptimizedImage.create_for enqueues jobs; run them in-process.
            Jobs.run_immediately!

            @avatar_sizes = Discourse.avatar_sizes
            @system_user = Discourse.system_user
            @category_id = Category.last.id

            load_tracking_sets
          end

          def produce(emit_work:, emit_result:)
            # `upload_id` is the staging `uploads.id`; `source_id` is the original
            # id from `upload_results`, which is what the post/avatar sets below are
            # keyed on.
            sql = <<~SQL
              SELECT u.id AS upload_id, u.sha1 AS upload_sha1, r.id AS source_id, r.markdown
                FROM upload_results r
                     JOIN uploads u ON u.id = r.upload_id
               ORDER BY u.id
            SQL

            files_db.query(sql) do |row|
              upload_id = row[:upload_id]

              if @optimized_upload_ids.include?(upload_id) || !row[:markdown].start_with?("![")
                emit_result.call(skipped_status(upload_id))
              elsif @post_upload_ids.include?(row[:source_id])
                row[:type] = "post"
                emit_work.call(row)
              elsif @avatar_upload_ids.include?(row[:source_id])
                row[:type] = "avatar"
                emit_work.call(row)
              else
                emit_result.call(skipped_status(upload_id))
              end
            end
          end

          def build_worker_resource
            PostCreator.new(
              @system_user,
              raw: "Topic created by uploads_importer",
              acting_user: @system_user,
              skip_validations: true,
              title: "Topic created by uploads_importer - #{SecureRandom.hex}",
              archetype: Archetype.default,
              category: @category_id,
            ).create!
          end

          def process(row, post)
            retry_policy.run { attempt_optimization(row, post) } || error_status(row)
          rescue StandardError
            # Permanent failure, or a transient one past its retry budget.
            error_status(row)
          end

          def write(result)
            case result[:status]
            when :ok
              result[:optimized_images].each do |attributes|
                Database::FilesDB::OptimizedImage.create(**attributes)
              end
              :ok
            when :skipped
              :skip
            else
              :error
            end
          end

          private

          def load_tracking_sets
            [
              Thread.new { @optimized_upload_ids = load_optimized_upload_ids },
              Thread.new { @post_upload_ids = load_post_upload_ids },
              Thread.new { @avatar_upload_ids = load_avatar_upload_ids },
              Thread.new { @max_count = load_max_count },
            ].each(&:join)
          end

          def load_optimized_upload_ids
            load_existing_ids(files_db, "SELECT DISTINCT upload_id AS id FROM optimized_images")
          end

          def load_post_upload_ids
            set = Set.new
            intermediate_db.query(
              "SELECT upload_ids FROM posts WHERE upload_ids IS NOT NULL",
            ) { |row| JSON.parse(row[:upload_ids]).each { |id| set << id } }
            set
          end

          def load_avatar_upload_ids
            set = Set.new
            intermediate_db.query(
              "SELECT avatar_upload_id FROM users WHERE avatar_upload_id IS NOT NULL",
            ) { |row| set << row[:avatar_upload_id] }
            set
          end

          def load_max_count
            files_db.query_value("SELECT COUNT(*) FROM upload_results WHERE upload_id IS NOT NULL")
          end

          def attempt_optimization(row, post)
            upload = Upload.find_by(sha1: row[:upload_sha1])
            return if upload.nil?

            images = create_optimized_images(row[:type], row[:markdown], upload, post)
            return if images.blank?

            images = verify_optimized_images(images)
            return unless images_valid?(images)

            ok_status(row, images)
          end

          def create_optimized_images(type, markdown, upload, post)
            case type
            when "post"
              post.update_columns(baked_at: nil, cooked: "", raw: markdown)
              post.reload
              post.rebake!
              OptimizedImage.where(upload_id: upload.id).to_a
            when "avatar"
              @avatar_sizes.map { |size| OptimizedImage.create_for(upload, size, size) }
            end
          end

          def verify_optimized_images(images)
            images.map do |image|
              next if image.blank?

              image_path = add_multisite_prefix(discourse_store.get_path_for_optimized_image(image))
              next image if file_exists?(image_path)

              image.destroy
              nil
            end
          end

          def images_valid?(images)
            images.present? && images.all?(&:present?) && images.all?(&:persisted?) &&
              images.all? { |image| image.errors.blank? }
          end

          def ok_status(row, images)
            {
              id: row[:upload_id],
              status: :ok,
              optimized_images: images.map { |image| optimized_image_attributes(image) },
            }
          end

          def error_status(row)
            { id: row[:upload_id], status: :error }
          end

          def skipped_status(upload_id)
            { id: upload_id, status: :skipped }
          end

          def optimized_image_attributes(image)
            image.attributes.symbolize_keys.slice(*OPTIMIZED_IMAGE_COLUMNS)
          end

          def retry_policy
            @retry_policy ||= RetryPolicy.new(transient_errors: transient_error_classes)
          end

          def transient_error_classes
            classes = [ActiveRecord::Deadlocked, ActiveRecord::RecordNotUnique]
            classes << Aws::S3::Errors::ServiceError if defined?(Aws::S3::Errors::ServiceError)
            classes
          end
        end
      end
    end
  end
end

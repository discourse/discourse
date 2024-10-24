# frozen_string_literal: true

module Migrations::Uploader
  module Tasks
    class Optimizer < Base
      def initialize(databases, settings)
        super(databases, settings)

        @optimized_upload_ids = Set.new
        @post_upload_ids = Set.new
        @avatar_upload_ids = Set.new
        @max_count = 0

        @avatar_sizes = Discourse.avatar_sizes
      end

      def run!
        puts "", "Creating optimized images..."

        disable_optimized_image_lock

        init_threads.each(&:join)

        status_thread
        create_consumer_threads

        producer_thread.join
        work_queue.close
        consumer_threads.each(&:join)
        status_queue.close
        status_thread.join
      end

      def disable_optimized_image_lock
        # allow more than 1 thread to optimized images at the same time
        OptimizedImage.lock_per_machine = false
      end

      def init_threads
        [
          optimized_upload_ids_thread,
          post_upload_ids_thread,
          avatar_upload_ids_thread,
          max_count_thread,
        ]
      end

      def optimized_upload_ids_thread
        Thread.new do
          @uploads_db
            .db
            .query("SELECT id FROM optimized_images") { |row| @optimized_upload_ids << row[:id] }
        end
      end

      def post_upload_ids_thread
        Thread.new do
          sql = <<~SQL
          SELECT upload_ids
            FROM posts
           WHERE upload_ids IS NOT NULL
        SQL

          @intermediate_db
            .db
            .query(sql) { |row| JSON.parse(row[:upload_ids]).each { |id| @post_upload_ids << id } }
        end
      end

      def avatar_upload_ids_thread
        Thread.new do
          sql = <<~SQL
          SELECT avatar_upload_id
            FROM users
           WHERE avatar_upload_id IS NOT NULL
        SQL

          @intermediate_db.db.query(sql) { |row| @avatar_upload_ids << row[:avatar_upload_id] }
        end
      end

      def max_count_thread
        Thread.new do
          @max_count =
            @uploads_db.db.query_single_splat(
              "SELECT COUNT(*) FROM uploads WHERE upload IS NOT NULL",
            )
        end
      end

      def producer_thread
        Thread.new do
          sql = <<~SQL
            SELECT id AS upload_id, upload ->> 'sha1' AS upload_sha1, markdown
              FROM uploads
             WHERE upload IS NOT NULL
             ORDER BY rowid
          SQL

          @uploads_db
            .db
            .query(sql) do |row|
              upload_id = row[:upload_id]

              if @optimized_upload_ids.include?(upload_id) || !row[:markdown].start_with?("![")
                status_queue << { id: row[:upload_id], status: :skipped }
                next
              end

              if @post_upload_ids.include?(upload_id)
                row[:type] = "post"
                work_queue << row
              elsif @avatar_upload_ids.include?(upload_id)
                row[:type] = "avatar"
                work_queue << row
              else
                status_queue << { id: row[:upload_id], status: :skipped }
              end
            end
        end
      end

      def create_consumer_threads
        Jobs.run_immediately!

        thread_count.times { |index| consumer_threads << consumer_thread(index) }
      end

      def status_thread
        Thread.new do
          error_count = 0
          current_count = 0
          skipped_count = 0

          while !(params = status_queue.pop).nil?
            current_count += 1

            case params.delete(:status)
            when :ok
              uploads_db.insert(<<~SQL, params)
                INSERT INTO optimized_images (id, optimized_images)
                VALUES (:id, :optimized_images)
              SQL
            when :error
              error_count += 1
            when :skipped
              skipped_count += 1
            end

            log_status(error_count, current_count, skipped_count)
          end
        end
      end

      def log_status(error_count, current_count, skipped_count)
        error_count_text = error_count > 0 ? "#{error_count} errors".red : "0 errors"

        print "\r%7d / %7d (%s, %d skipped)" %
                [current_count, @max_count, error_count_text, skipped_count]
      end

      def consumer_thread(index)
        Thread.new do
          Thread.current.name = "worker-#{index}"

          post =
            PostCreator.new(
              Discourse.system_user,
              raw: "Topic created by uploads_importer",
              acting_user: Discourse.system_user,
              skip_validations: true,
              title: "Topic created by uploads_importer - #{SecureRandom.hex}",
              archetype: Archetype.default,
              category: Category.last.id,
            ).create!

          while (row = work_queue.pop)
            process_row(row, post)
          end
        end
      end

      def process_row(row, post)
        retry_count = 0

        loop do
          upload = Upload.find_by(sha1: row[:upload_sha1])
          optimized_images = create_optimized_images(row[:type], row[:markdown], upload, post)

          optimized_images = process_optimized_images(optimized_images) if optimized_images.present?

          optimized_images_okay =
            !optimized_images.nil? && optimized_images.all?(&:present?) &&
              optimized_images.all?(&:persisted?) && optimized_images.all? { |o| o.errors.blank? }

          if optimized_images_okay
            status_queue << {
              id: row[:upload_id],
              optimized_images: optimized_images.presence&.to_json,
              status: :ok,
            }

            break
          elsif retry_count >= 3
            status_queue << { id: row[:upload_id], status: :error }
            break
          end

          retry_count += 1
          sleep 0.25 * retry_count
        end
      end

      def create_optimized_images(type, markdown, upload, post)
        case type
        when "post"
          post.update_columns(baked_at: nil, cooked: "", raw: markdown)
          post.reload
          post.rebake!

          OptimizedImage.where(upload_id: upload.id).to_a
        when "avatar"
          avatar_sizes.map { |size| OptimizedImage.create_for(upload, size, size) }
        end
      rescue StandardError => e
        puts e.message
        puts e.stacktrace

        nil
      end

      def process_optimized_images(images)
        begin
          images.map! do |image|
            next if image.blank?

            image_path = add_multisite_prefix(discourse_store.get_path_for_optimized_image(image))

            unless file_exists?(image_path)
              image.destroy
              image = nil
            end

            image
          end
        rescue StandardError
          images = nil
        end

        images
      end
    end
  end
end

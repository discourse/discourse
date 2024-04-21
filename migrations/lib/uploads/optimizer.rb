# frozen_string_literal: true

require_relative "./base"

module Migrations
  module Uploads
    class Optimizer < Base
      def initialize(settings)
        @settings = settings

        @source_db = create_connection(@settings[:source_db_path])
        @output_db = settings.output_db
      end

      def self.run!(settings)
        puts "Creating optimized images..."

        new(settings).run!
      end

      def run!
        init_threads = []
        optimized_upload_ids = Set.new
        post_upload_ids = Set.new
        avatar_upload_ids = Set.new
        max_count = 0

        # allow more than 1 thread to optimized images at the same time
        OptimizedImage.lock_per_machine = false

        init_threads << Thread.new do
          query("SELECT id FROM optimized_images", @output_db).tap do |result_set|
            result_set.each { |row| optimized_upload_ids << row["id"] }
            result_set.close
          end
        end

        init_threads << Thread.new do
          sql = <<~SQL
          SELECT upload_ids
            FROM posts
           WHERE upload_ids IS NOT NULL
        SQL
          query(sql, @source_db).tap do |result_set|
            result_set.each do |row|
              JSON.parse(row["upload_ids"]).each { |id| post_upload_ids << id }
            end
            result_set.close
          end
        end

        init_threads << Thread.new do
          sql = <<~SQL
          SELECT avatar_upload_id
            FROM users
           WHERE avatar_upload_id IS NOT NULL
        SQL
          query(sql, @source_db).tap do |result_set|
            result_set.each { |row| avatar_upload_ids << row["avatar_upload_id"] }
            result_set.close
          end
        end

        init_threads << Thread.new do
          max_count =
            @output_db.get_first_value("SELECT COUNT(*) FROM uploads WHERE upload IS NOT NULL")
        end

        init_threads.each(&:join)

        status_queue = SizedQueue.new(QUEUE_SIZE)
        status_thread =
          Thread.new do
            error_count = 0
            current_count = 0
            skipped_count = 0

            while !(params = status_queue.pop).nil?
              current_count += 1

              case params.delete(:status)
              when :ok
                @output_db.execute(<<~SQL, params)
                  INSERT INTO optimized_images (id, optimized_images)
                  VALUES (:id, :optimized_images)
                SQL
              when :error
                error_count += 1
              when :skipped
                skipped_count += 1
              end

              error_count_text = error_count > 0 ? "#{error_count} errors".red : "0 errors"

              print "\r%7d / %7d (%s, %d skipped)" %
                      [current_count, max_count, error_count_text, skipped_count]
            end
          end

        queue = SizedQueue.new(QUEUE_SIZE)
        consumer_threads = []

        producer_thread =
          Thread.new do
            sql = <<~SQL
              SELECT id AS upload_id, upload ->> 'sha1' AS upload_sha1, markdown
                FROM uploads
               WHERE upload IS NOT NULL
               ORDER BY rowid
            SQL

            query(sql, @output_db).tap do |result_set|
              result_set.each do |row|
                upload_id = row["upload_id"]

                if optimized_upload_ids.include?(upload_id) || !row["markdown"].start_with?("![")
                  status_queue << { id: row["upload_id"], status: :skipped }
                  next
                end

                if post_upload_ids.include?(upload_id)
                  row["type"] = "post"
                  queue << row
                elsif avatar_upload_ids.include?(upload_id)
                  row["type"] = "avatar"
                  queue << row
                else
                  status_queue << { id: row["upload_id"], status: :skipped }
                end
              end
              result_set.close
            end
          end

        avatar_sizes = Discourse.avatar_sizes
        store = Discourse.store
        remote_factor = store.external? ? 2 : 1

        Jobs.run_immediately!

        (Etc.nprocessors * @settings[:thread_count_factor] * remote_factor).to_i.times do |index|
          consumer_threads << Thread.new do
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

            while (row = queue.pop)
              retry_count = 0

              loop do
                upload = Upload.find_by(sha1: row["upload_sha1"])

                optimized_images =
                  begin
                    case row["type"]
                    when "post"
                      post.update_columns(baked_at: nil, cooked: "", raw: row["markdown"])
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

                begin
                  if optimized_images.present?
                    optimized_images.map! do |optimized_image|
                      next unless optimized_image.present?
                      optimized_image_path =
                        add_multisite_prefix(store.get_path_for_optimized_image(optimized_image))

                      file_exists =
                        if store.external?
                          store.object_from_path(optimized_image_path).exists?
                        else
                          File.exist?(File.join(store.public_dir, optimized_image_path))
                        end

                      unless file_exists
                        optimized_image.destroy
                        optimized_image = nil
                      end

                      optimized_image
                    end
                  end
                rescue StandardError
                  optimized_images = nil
                end

                optimized_images_okay =
                  !optimized_images.nil? && optimized_images.all?(&:present?) &&
                    optimized_images.all?(&:persisted?) &&
                    optimized_images.all? { |o| o.errors.blank? }

                if optimized_images_okay
                  status_queue << {
                    id: row["upload_id"],
                    optimized_images: optimized_images.presence&.to_json,
                    status: :ok,
                  }
                  break
                elsif retry_count >= 3
                  status_queue << { id: row["upload_id"], status: :error }
                  break
                end

                retry_count += 1
                sleep 0.25 * retry_count
              end
            end
          end
        end

        producer_thread.join
        queue.close
        consumer_threads.each(&:join)
        status_queue.close
        status_thread.join
      end
    end
  end
end

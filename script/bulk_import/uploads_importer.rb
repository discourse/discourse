# frozen_string_literal: true
puts "Loading application..."
require_relative "../../config/environment"

require "etc"
require "sqlite3"
require "colored2"

# hack so that OptimizedImage.lock beliefs that it's running in a Sidekiq job
module Sidekiq
  def self.server?
    true
  end
end

module BulkImport
  class UploadsImporter
    TRANSACTION_SIZE = 1000
    QUEUE_SIZE = 1000

    def initialize(settings_path)
      @settings = YAML.load_file(settings_path, symbolize_names: true)

      @root_path = @settings[:root_path]
      @output_db = create_connection(@settings[:output_db_path])

      initialize_output_db
      configure_site_settings
    end

    def run
      # disable logging for EXIFR which is used by ImageOptim
      EXIFR.logger = Logger.new(nil)

      if @settings[:fix_missing]
        @source_db = create_connection(@settings[:output_db_path])

        puts "Fixing missing uploads..."
        fix_missing
      else
        @source_db = create_connection(@settings[:source_db_path])

        puts "Uploading uploads..."
        upload_files

        puts "", "Creating optimized images..."
        if @settings[:create_optimized_images]
          begin
            @source_db.execute("ATTACH DATABASE ? AS discourse", @settings[:output_db_path])
            create_optimized_images
          ensure
            @source_db.execute("DETACH DATABASE discourse", @settings[:output_db_path])
          end
        end
      end
      puts ""
    ensure
      close
    end

    def upload_files
      queue = SizedQueue.new(QUEUE_SIZE)
      consumer_threads = []

      if @settings[:delete_missing_uploads]
        puts "Deleting missing uploads from output database..."
        @output_db.execute(<<~SQL)
          DELETE FROM uploads
          WHERE upload IS NULL
        SQL
      end

      output_existing_ids = Set.new
      query("SELECT id FROM uploads", @output_db).tap do |result_set|
        result_set.each { |row| output_existing_ids << row["id"] }
        result_set.close
      end

      source_existing_ids = Set.new
      query("SELECT id FROM uploads", @source_db).tap do |result_set|
        result_set.each { |row| source_existing_ids << row["id"] }
        result_set.close
      end

      if (surplus_upload_ids = output_existing_ids - source_existing_ids).any?
        if @settings[:delete_surplus_uploads]
          puts "Deleting #{surplus_upload_ids.size} uploads from output database..."

          surplus_upload_ids.each_slice(TRANSACTION_SIZE) do |ids|
            placeholders = (["?"] * ids.size).join(",")
            @output_db.execute(<<~SQL, ids)
              DELETE FROM uploads
              WHERE id IN (#{placeholders})
            SQL
          end

          output_existing_ids -= surplus_upload_ids
        else
          puts "Found #{surplus_upload_ids.size} surplus uploads in output database. " \
                 "Run with `delete_surplus_uploads: true` to delete them."
        end

        surplus_upload_ids = nil
      end

      max_count = (source_existing_ids - output_existing_ids).size
      source_existing_ids = nil
      puts "Found #{output_existing_ids.size} existing uploads. #{max_count} are missing."

      producer_thread =
        Thread.new do
          query("SELECT * FROM uploads", @source_db).tap do |result_set|
            result_set.each { |row| queue << row unless output_existing_ids.include?(row["id"]) }
            result_set.close
          end
        end

      status_queue = SizedQueue.new(QUEUE_SIZE)
      status_thread =
        Thread.new do
          error_count = 0
          skipped_count = 0
          current_count = 0

          while !(params = status_queue.pop).nil?
            begin
              if params.delete(:skipped) == true
                skipped_count += 1
              elsif (error_message = params.delete(:error)) || params[:upload].nil?
                error_count += 1
                puts "", "Failed to create upload: #{params[:id]} (#{error_message})", ""
              end

              @output_db.execute(<<~SQL, params)
                INSERT INTO uploads (id, upload, markdown, skip_reason)
                VALUES (:id, :upload, :markdown, :skip_reason)
              SQL
            rescue StandardError => e
              puts "", "Failed to insert upload: #{params[:id]} (#{e.message}))", ""
              error_count += 1
            end

            current_count += 1
            error_count_text = error_count > 0 ? "#{error_count} errors".red : "0 errors"

            print "\r%7d / %7d (%s, %d skipped)" %
                    [current_count, max_count, error_count_text, skipped_count]
          end
        end

      (Etc.nprocessors * @settings[:thread_count_factor]).to_i.times do |index|
        consumer_threads << Thread.new do
          Thread.current.name = "worker-#{index}"

          store = Discourse.store

          while (row = queue.pop)
            begin
              path = File.join(@root_path, row["relative_path"], row["filename"])

              if !File.exist?(path)
                status_queue << {
                  id: row["id"],
                  upload: nil,
                  skipped: true,
                  skip_reason: "file not found",
                }
                next
              end

              retry_count = 0

              loop do
                error_message = nil
                upload =
                  copy_to_tempfile(path) do |file|
                    begin
                      UploadCreator.new(file, row["filename"], type: row["type"]).create_for(
                        Discourse::SYSTEM_USER_ID,
                      )
                    rescue StandardError => e
                      error_message = e.message
                      nil
                    end
                  end

                if upload.present?
                  upload_path = store.get_path_for_upload(upload)

                  file_exists =
                    if store.external?
                      store.object_from_path(upload_path).exists?
                    else
                      File.exist?(File.join(store.public_dir, upload_path))
                    end

                  unless file_exists
                    upload.destroy
                    upload = nil
                  end
                end

                upload_okay = upload.present? && upload.persisted? && upload.errors.blank?

                if upload_okay
                  status_queue << {
                    id: row["id"],
                    upload: upload.attributes.to_json,
                    markdown: UploadMarkdown.new(upload).to_markdown,
                    skip_reason: nil,
                  }
                  break
                elsif retry_count >= 3
                  error_message ||= upload&.errors&.full_messages&.join(", ") || "unknown error"
                  status_queue << {
                    id: row["id"],
                    upload: nil,
                    markdown: nil,
                    error: "too many retries: #{error_message}",
                    skip_reason: "too many retries",
                  }
                  break
                end

                retry_count += 1
                sleep 0.25 * retry_count
              end
            rescue StandardError => e
              status_queue << {
                id: row["id"],
                upload: nil,
                markdown: nil,
                error: e.message,
                skip_reason: "error",
              }
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

    def fix_missing
      queue = SizedQueue.new(QUEUE_SIZE)
      consumer_threads = []

      max_count =
        @source_db.get_first_value("SELECT COUNT(*) FROM uploads WHERE upload IS NOT NULL")

      producer_thread =
        Thread.new do
          query(
            "SELECT id, upload FROM uploads WHERE upload IS NOT NULL ORDER BY rowid DESC",
            @source_db,
          ).tap do |result_set|
            result_set.each { |row| queue << row }
            result_set.close
          end
        end

      status_queue = SizedQueue.new(QUEUE_SIZE)
      status_thread =
        Thread.new do
          error_count = 0
          current_count = 0
          missing_count = 0

          while !(result = status_queue.pop).nil?
            current_count += 1

            case result[:status]
            when :ok
              # ignore
            when :error
              error_count += 1
              puts "Error in #{result[:id]}"
            when :missing
              missing_count += 1
              puts "Missing #{result[:id]}"

              @output_db.execute("DELETE FROM uploads WHERE id = ?", result[:id])
              Upload.delete_by(id: result[:upload_id])
            end

            error_count_text = error_count > 0 ? "#{error_count} errors".red : "0 errors"

            print "\r%7d / %7d (%s, %s missing)" %
                    [current_count, max_count, error_count_text, missing_count]
          end
        end

      store = Discourse.store

      (Etc.nprocessors * @settings[:thread_count_factor] * 2).to_i.times do |index|
        consumer_threads << Thread.new do
          Thread.current.name = "worker-#{index}"
          fake_upload = OpenStruct.new(url: "")
          while (row = queue.pop)
            begin
              upload = JSON.parse(row["upload"])
              fake_upload.url = upload["url"]
              path = store.get_path_for_upload(fake_upload)

              file_exists =
                if store.external?
                  store.object_from_path(path).exists?
                else
                  File.exist?(File.join(store.public_dir, path))
                end

              if file_exists
                status_queue << { id: row["id"], upload_id: upload["id"], status: :ok }
              else
                status_queue << { id: row["id"], upload_id: upload["id"], status: :missing }
              end
            rescue StandardError => e
              puts e.message
              status_queue << { id: row["id"], upload_id: upload["id"], status: :error }
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

    def create_optimized_images
      optimized_upload_ids = Set.new
      query("SELECT id FROM optimized_images", @output_db).tap do |result_set|
        result_set.each { |row| optimized_upload_ids << row["id"] }
        result_set.close
      end

      queue = SizedQueue.new(QUEUE_SIZE)
      consumer_threads = []

      max_count =
        @output_db.get_first_value("SELECT COUNT(*) FROM uploads WHERE upload IS NOT NULL")

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

      producer_thread =
        Thread.new do
          sql = <<~SQL
            SELECT u.avatar_upload_id AS upload_id, du.upload ->> 'sha1' AS upload_sha1, du.markdown, 'avatar' AS type
              FROM users u
                   JOIN discourse.uploads du ON u.avatar_upload_id = du.id
             WHERE u.avatar_upload_id IS NOT NULL
             UNION ALL
            SELECT pu.value AS upload_id, du.upload ->> 'sha1' AS upload_sha1, du.markdown, 'post' AS type
              FROM posts p,
                   JSON_EACH(p.upload_ids) pu,
                   discourse.uploads du
             WHERE p.upload_ids IS NOT NULL
               AND pu.value = du.id
          SQL

          query(sql, @source_db).tap do |result_set|
            result_set.each do |row|
              if optimized_upload_ids.include?(row["id"])
                queue << row
              else
                status_queue << { id: row["id"], status: :skipped }
              end
            end
            result_set.close
          end
        end

      avatar_sizes = Discourse.avatar_sizes
      store = Discourse.store

      Jobs.run_immediately!

      (Etc.nprocessors * @settings[:thread_count_factor]).to_i.times do |index|
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

              if !row["markdown"].start_with?("![")
                status_queue << { id: row["id"], status: :skipped }
                next
              end

              optimized_images =
                begin
                  case row["type"]
                  when "post"
                    post.update_columns(baked_at: nil, cooked: "", raw: row["markdown"])
                    post.reload
                    post.rebake!
                    OptimizedImage.where(upload_id: upload.id)
                  when "avatar"
                    avatar_sizes.map { |size| OptimizedImage.create_for(upload, size, size) }
                  end
                rescue StandardError => e
                  puts e.message
                  puts e.stacktrace
                  nil
                end

              if optimized_images.present?
                optimized_images.map! do |optimized_image|
                  next unless optimized_image.present?
                  optimized_image_path = store.get_path_for_optimized_image(optimized_image)

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

              optimized_images_okay =
                !optimized_images.nil? && optimized_images.all?(&:present?) &&
                  optimized_images.all?(&:persisted?) &&
                  optimized_images.all? { |o| o.errors.blank? }

              if optimized_images_okay
                status_queue << {
                  id: row["id"],
                  optimized_images: optimized_images.to_json,
                  status: :ok,
                }
                break
              elsif retry_count >= 3
                status_queue << { id: row["id"], status: :error }
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

    private

    def create_connection(path)
      sqlite = SQLite3::Database.new(path, results_as_hash: true)
      sqlite.busy_timeout = 60_000 # 60 seconds
      sqlite.journal_mode = "WAL"
      sqlite.synchronous = "off"
      sqlite
    end

    def query(sql, db)
      db.prepare(sql).execute
    end

    def initialize_output_db
      @statement_counter = 0

      @output_db.execute(<<~SQL)
        CREATE TABLE IF NOT EXISTS uploads (
          id TEXT PRIMARY KEY,
          upload JSON_TEXT,
          markdown TEXT,
          skip_reason TEXT
        )
      SQL

      @output_db.execute(<<~SQL)
        CREATE TABLE IF NOT EXISTS optimized_images (
          id TEXT PRIMARY KEY,
          optimized_images JSON_TEXT
        )
      SQL
    end

    def insert(sql, bind_vars = [])
      @output_db.transaction if @statement_counter == 0
      @output_db.execute(sql, bind_vars)

      if (@statement_counter += 1) > TRANSACTION_SIZE
        @output_db.commit
        @statement_counter = 0
      end
    end

    def close
      @source_db.close if @source_db

      if @output_db
        @output_db.commit if @output_db.transaction_active?
        @output_db.close
      end
    end

    def copy_to_tempfile(source_path)
      extension = File.extname(source_path)

      Tempfile.open(["discourse-upload", extension]) do |tmpfile|
        File.open(source_path, "rb") { |source_stream| IO.copy_stream(source_stream, tmpfile) }
        tmpfile.rewind
        yield(tmpfile)
      end
    end

    def format_datetime(value)
      value ? value.utc.iso8601 : nil
    end

    def format_boolean(value)
      return nil if value.nil?
      value ? 1 : 0
    end

    def configure_site_settings
      settings = @settings[:site_settings]

      SiteSetting.clean_up_uploads = false
      SiteSetting.authorized_extensions = settings[:authorized_extensions]
      SiteSetting.max_attachment_size_kb = settings[:max_attachment_size_kb]
      SiteSetting.max_image_size_kb = settings[:max_image_size_kb]

      if settings[:enable_s3_uploads]
        SiteSetting.s3_access_key_id = settings[:s3_access_key_id]
        SiteSetting.s3_secret_access_key = settings[:s3_secret_access_key]
        SiteSetting.s3_upload_bucket = settings[:s3_upload_bucket]
        SiteSetting.s3_region = settings[:s3_region]
        SiteSetting.s3_cdn_url = settings[:s3_cdn_url]
        SiteSetting.enable_s3_uploads = true

        raise "Failed to enable S3 uploads" if SiteSetting.enable_s3_uploads != true

        Tempfile.open("discourse-s3-test") do |tmpfile|
          tmpfile.write("test")
          tmpfile.rewind

          upload =
            UploadCreator.new(tmpfile, "discourse-s3-test.txt").create_for(
              Discourse::SYSTEM_USER_ID,
            )

          unless upload.present? && upload.persisted? && upload.errors.blank? &&
                   upload.url.start_with?("//")
            raise "Failed to upload to S3"
          end

          upload.destroy
        end
      end
    end
  end
end

# bundle exec ruby script/bulk_import/uploads_importer.rb /path/to/uploads_importer.yml
BulkImport::UploadsImporter.new(ARGV.first).run

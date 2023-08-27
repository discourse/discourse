# frozen_string_literal: true
puts "Loading application..."
require_relative "../../config/environment"

require "etc"
require "sqlite3"
require "colored2"

module BulkImport
  class UploadsImporter
    TRANSACTION_SIZE = 1000
    QUEUE_SIZE = 1000

    def initialize(settings_path)
      @settings = YAML.load_file(settings_path, symbolize_names: true)

      @source_db = create_connection(@settings[:source_db_path])
      @output_db = create_connection(@settings[:output_db_path])
      @root_path = @settings[:root_path]

      initialize_output_db
      configure_site_settings
    end

    def run
      # disable logging for EXIFR which is used by ImageOptim
      EXIFR.logger = Logger.new(nil)

      queue = SizedQueue.new(QUEUE_SIZE)
      consumer_threads = []

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

      surplus_upload_ids = output_existing_ids - source_existing_ids

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
                INSERT INTO uploads (id, upload, skip_reason)
                VALUES (:id, :upload, :skip_reason)
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

                upload_okay = upload.present? && upload.persisted? && upload.errors.blank?

                if upload_okay
                  status_queue << {
                    id: row["id"],
                    upload: upload.attributes.to_json,
                    skip_reason: nil,
                  }
                  break
                elsif retry_count >= 3
                  error_message ||= upload&.errors&.full_messages&.join(", ") || "unknown error"
                  status_queue << {
                    id: row["id"],
                    upload: nil,
                    error: "too many retries: #{error_message}",
                    skip_reason: "too many retries",
                  }
                  break
                end

                retry_count += 1
                sleep 0.25 * retry_count
              end
            rescue StandardError => e
              status_queue << { id: row["id"], upload: nil, error: e.message, skip_reason: "error" }
            end
          end
        end
      end

      producer_thread.join
      queue.close
      consumer_threads.each(&:join)
      status_queue.close
      status_thread.join
    ensure
      close
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
          skip_reason TEXT
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

# bundle exec ruby script/bulk_import/uploads_importer.rb /path/to/settings.yml
BulkImport::UploadsImporter.new(ARGV.first).run

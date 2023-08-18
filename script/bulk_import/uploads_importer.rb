# frozen_string_literal: true
puts "Loading application..."
require_relative "../../config/environment"

require "etc"
require "sqlite3"

module BulkImport
  class UploadsImporter
    def initialize(source_db_path, output_db_path, root_path)
      @source_db = create_connection(source_db_path)
      @output_db = create_connection(output_db_path)
      @root_path = root_path

      initialize_output_db
    end

    def run
      queue = SizedQueue.new(1000)
      threads = []

      threads << Thread.new do ||
        query("SELECT * FROM uploads").each { |row| queue << row }
        queue.close
      end

      max_count = @source_db.get_first_value("SELECT COUNT(*) FROM uploads")

      status_queue = Queue.new
      status_thread =
        Thread.new do
          error_count = 0
          current_count = 0

          while (params = status_queue.pop).present?
            if params == false
              error_count += 1
            else
              @output_db.execute(<<~SQL, params)
                INSERT INTO uploads (id, upload)
                VALUES (:id, :upload)
              SQL
            end

            current_count += 1

            print "\r%7d / %7d (%d errors)" % [current_count, max_count, error_count]
          end
        end

      (Etc.nprocessors / 2).times do
        threads << Thread.new do
          while (row = queue.pop)
            begin
              path = File.join(@root_path, row["relative_path"], row["filename"])
              next unless File.exist?(path)

              copy_to_tempfile(path) do |file|
                upload =
                  UploadCreator.new(file, row["filename"], type: "avatar").create_for(
                    Discourse::SYSTEM_USER_ID,
                  )

                status_queue << { id: row["id"], upload: upload.attributes.to_json }
              end
            rescue StandardError
              status_queue << false
            end
          end
        end
      end

      threads.each(&:join)
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

    def query(sql)
      @source_db.prepare(sql).execute
    end

    def initialize_output_db
      @output_db.execute(<<~SQL)
        CREATE TABLE IF NOT EXISTS uploads (
          id TEXT PRIMARY KEY,
          upload JSON_TEXT
        )
      SQL
    end

    def copy_to_tempfile(source_path)
      extension = File.extname(source_path)

      Tempfile.open(["discourse-upload", extension]) do |tmpfile|
        File.open(source_path, "rb") { |source_stream| IO.copy_stream(source_stream, tmpfile) }
        tmpfile.rewind
        yield(tmpfile)
        tmpfile
      end
    end

    def format_datetime(value)
      value ? value.utc.iso8601 : nil
    end

    def format_boolean(value)
      return nil if value.nil?
      value ? 1 : 0
    end
  end
end

# bundle exec ruby script/bulk_import/uploads_importer.rb /path/to/source.db /path/to/output.db /path/to/uploads
BulkImport::UploadsImporter.new(ARGV[0], ARGV[1], ARGV[2]).run

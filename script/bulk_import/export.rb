# frozen_string_literal: true
puts "Loading application..."
require_relative "../../config/environment"

require "sqlite3"

class Exporter
  TRANSACTION_SIZE = 1000
  PATH = "/shared/import/optimize_images.db"

  def initialize
    @db = create_connection(PATH)
  end

  def run
    export
    upload_db
  end

  private

  def export
    initialize_output_db

    upload_id_mapping =
      DB.query_array(
        "SELECT discourse_id::INT, original_id FROM migration_mappings WHERE type = 1",
      ).to_h

    current_count = 0
    optimized_images = []
    last_upload_id = nil

    DB
      .query_hash("SELECT * FROM optimized_images ORDER BY upload_id, id")
      .each do |row|
        original_upload_id = upload_id_mapping[row["upload_id"]]
        next unless original_upload_id

        if last_upload_id == original_upload_id
          optimized_images << row
        else
          insert_optimized_images(last_upload_id, optimized_images) if last_upload_id
          optimized_images = [row]
          last_upload_id = original_upload_id
        end

        current_count += 1
        print "\r%7d" % [current_count]
      end

    if last_upload_id && optimized_images.any?
      insert_optimized_images(last_upload_id, optimized_images)
    end
  ensure
    close
  end

  def upload_db
    s3_options = S3Helper.s3_options(SiteSetting)
    s3_bucket_name_with_prefix =
      File.join(SiteSetting.s3_backup_bucket, RailsMultisite::ConnectionManagement.current_db)
    s3_helper = S3Helper.new(s3_bucket_name_with_prefix, "", s3_options.clone)

    obj = s3_helper.object("optimize_images.db")
    obj.upload_file(PATH, content_type: "application/x-sqlite3")
  end

  def create_connection(path)
    sqlite = SQLite3::Database.new(path, results_as_hash: true)
    sqlite.busy_timeout = 60_000 # 60 seconds
    sqlite.journal_mode = "WAL"
    sqlite.synchronous = "off"
    sqlite
  end

  def query(sql, *bind_vars)
    @db.prepare(sql).execute(*bind_vars)
  end

  def initialize_output_db
    @statement_counter = 0

    @db.execute(<<~SQL)
    CREATE TABLE IF NOT EXISTS optimized_images (
      id TEXT PRIMARY KEY,
      optimized_images JSON_TEXT
    )
  SQL
  end

  def insert(sql, bind_vars = [])
    @db.transaction if @statement_counter == 0
    @db.execute(sql, bind_vars)

    if (@statement_counter += 1) > TRANSACTION_SIZE
      @db.commit
      @statement_counter = 0
    end
  end

  def close
    @db.commit if @db.transaction_active?
    @db.close
  end

  def insert_optimized_images(upload_id, optimized_images)
    insert(
      "INSERT INTO optimized_images (id, optimized_images) VALUES (?, ?)",
      [upload_id, optimized_images.to_json],
    )
  end
end

Exporter.new.run

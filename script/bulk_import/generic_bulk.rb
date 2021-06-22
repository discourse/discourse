# frozen_string_literal: true

require_relative "base"
require "sqlite3"

class BulkImport::Generic < BulkImport::Base
  AVATAR_DIRECTORY = ENV["AVATAR_DIRECTORY"]
  UPLOAD_DIRECTORY = ENV["UPLOAD_DIRECTORY"]

  def initialize(db_path)
    super()
    @db = create_connection(db_path)
  end

  def start
    run # will call execute, and then "complete" the migration

    # Now that the migration is complete, do some more work:

    Discourse::Application.load_tasks
    Rake::Task["import:ensure_consistency"].invoke
  end

  def execute
    import_groups
    import_users
  end

  def import_groups
    puts "Importing groups..."

    groups = @db.execute(<<~SQL, last_row_id: @last_imported_group_id)
      SELECT *
      FROM groups
      WHERE ROWID > :last_row_id #{}
      ORDER BY ROWID
    SQL

    create_groups(groups) do |row|
      {
        imported_id: row["id"],
        name: normalize_text("name")
      }
    end
  end

  def import_users
    puts "Importing users..."

    users = @db.execute(<<~SQL, last_row_id: @last_imported_user_id)
      SELECT ROWID, *
      FROM users
      WHERE ROWID > :last_row_id
      ORDER BY ROWID
    SQL

    create_users(users) do |row|
      {
        imported_id: row["id"],
        username: row["username"],
        created_at: to_datetime(row["created_at"]),
        name: row["name"],
        email: row["email"],
        last_seen_at: to_datetime(row[:"last_seen_at"]),
        bio_raw: row["bio"],
        location: row["location"],
        admin: to_boolean(row["admin"]),
        moderator: to_boolean(row["moderator"])
      }
    end
  end

  def create_connection(path)
    sqlite = SQLite3::Database.new(path, results_as_hash: true)
    sqlite.busy_timeout = 60000 # 60 seconds
    sqlite.auto_vacuum = "full"
    sqlite.foreign_keys = true
    sqlite.journal_mode = "wal"
    sqlite.synchronous = "normal"
    sqlite
  end

  def to_date(text)
    text.present? ? Date.parse(text) : nil
  end

  def to_datetime(text)
    text.present? ? DateTime.parse(text) : nil
  end

  def to_boolean(value)
    value == 1
  end
end

BulkImport::Generic.new(ARGV.first).start

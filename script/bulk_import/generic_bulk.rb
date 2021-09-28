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
    import_users
    import_user_emails
    import_topics
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
        email: row["email"],
        created_at: to_datetime(row["created_at"])
      }
    end
  end

  def import_user_emails
    puts '', 'Importing user emails...'

    users = @db.execute(<<~SQL, last_row_id: @last_imported_user_id)
      SELECT ROWID, *
      FROM users
      WHERE ROWID > :last_row_id
      ORDER BY ROWID
    SQL

    create_user_emails(users) do |row|
      {
        imported_id: row["id"],
        imported_user_id: row["id"],
        email: row["email"],
        created_at: to_datetime(row["created_at"])
      }
    end
  end

  def import_topics
    puts "Importing topics..."

    topics = @db.execute(<<~SQL, last_row_id: @last_imported_topic_id)
      SELECT ROWID, *
      FROM topics
      WHERE ROWID > :last_row_id
      ORDER BY ROWID
    SQL

    create_topics(topics) do |row|
      {
        imported_id: row["id"],
        title: normalize_text(row["title"]),
        user_id: user_id_from_imported_id(row["user_id"]),
        created_at: to_datetime(row["created_at"]),
        category_id: 1
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

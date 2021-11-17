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
    import_categories
    import_users
    import_user_emails
    import_single_sign_on_records
    import_topics
    import_posts
  end

  def import_categories
    puts "Importing categories..."

    categories = @db.execute(<<~SQL)
      WITH RECURSIVE tree(id, parent_category_id, name, description, color, text_color, read_restricted, slug,
                          old_relative_url, existing_id, level, rowid) AS (
          SELECT c.id, c.parent_category_id, c.name, c.description, c.color, c.text_color, c.read_restricted, c.slug,
                 c.old_relative_url, c.existing_id, 0 AS level, c.ROWID
          FROM categories c
          WHERE c.parent_category_id IS NULL
          UNION
          SELECT c.id, c.parent_category_id, c.name, c.description, c.color, c.text_color, c.read_restricted, c.slug,
                 c.old_relative_url, c.existing_id, tree.level + 1 AS level, c.ROWID
          FROM categories c,
               tree
          WHERE c.parent_category_id = tree.id
      )
      SELECT *
      FROM tree
      ORDER BY level, rowid
    SQL

    create_categories(categories) do |row|
      {
        imported_id: row["id"],
        existing_id: row["existing_id"],
        name: row["name"],
        description: row["description"],
        parent_category_id: row["parent_category_id"] ? category_id_from_imported_id(row["parent_category_id"]) : nil,
        slug: row["slug"]
      }
    end
  end

  def import_users
    puts "Importing users..."

    users = @db.execute(<<~SQL)
      SELECT ROWID, *
      FROM users
      ORDER BY ROWID
    SQL

    create_users(users) do |row|
      sso_record = JSON.parse(row["sso_record"]) if row["sso_record"].present?

      {
        imported_id: row["id"],
        username: row["username"],
        email: row["email"],
        external_id: sso_record&.fetch("external_id"),
        created_at: to_datetime(row["created_at"])
      }
    end
  end

  def import_user_emails
    puts '', 'Importing user emails...'

    users = @db.execute(<<~SQL)
      SELECT ROWID, id, email, created_at
      FROM users
      ORDER BY ROWID
    SQL

    create_user_emails(users) do |row|
      {
        # FIXME: using both "imported_id" and "imported_user_id" and should be replaced by just "imported_id"
        imported_id: row["id"],
        imported_user_id: row["id"],
        email: row["email"],
        created_at: to_datetime(row["created_at"])
      }
    end
  end

  def import_single_sign_on_records
    puts '', 'Importing SSO records...'

    users = @db.execute(<<~SQL)
      SELECT ROWID, id, sso_record
      FROM users
      WHERE sso_record IS NOT NULL
      ORDER BY ROWID
    SQL

    create_single_sign_on_records(users) do |row|
      sso_record = JSON.parse(row["sso_record"], symbolize_names: true)
      # FIXME: using both "imported_id" and "imported_user_id" and should be replaced by just "imported_id"
      sso_record[:imported_id] = row["id"]
      sso_record[:imported_user_id] = row["id"]
      sso_record
    end
  end

  def import_topics
    puts "Importing topics..."

    topics = @db.execute(<<~SQL)
      SELECT ROWID, *
      FROM topics
      ORDER BY ROWID
    SQL

    create_topics(topics) do |row|
      {
        imported_id: row["id"],
        title: row["title"],
        user_id: user_id_from_imported_id(row["user_id"]),
        created_at: to_datetime(row["created_at"]),
        category_id: category_id_from_imported_id(row["category_id"])
      }
    end

    puts "Importing first posts..."
    topics = @db.execute(<<~SQL)
      SELECT ROWID, *
      FROM topics
      ORDER BY ROWID
    SQL

    create_posts(topics) do |row|
      next if row["raw"].blank?
      next unless topic_id = topic_id_from_imported_id(row["id"])

      {
        imported_id: row["id"],
        topic_id: topic_id,
        user_id: user_id_from_imported_id(row["user_id"]),
        created_at: to_datetime(row["created_at"]),
        raw: row["raw"]
      }
    end
  end

  def import_posts
    puts "Importing posts..."

    posts = @db.execute(<<~SQL)
      SELECT ROWID, *
      FROM posts
      ORDER BY topic_id, post_number
    SQL

    create_posts(posts) do |row|
      next if row["raw"].blank?
      next unless topic_id = topic_id_from_imported_id(row["topic_id"])

      {
        imported_id: row["id"],
        topic_id: topic_id,
        user_id: user_id_from_imported_id(row["user_id"]),
        created_at: to_datetime(row["created_at"]),
        raw: row["raw"]
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

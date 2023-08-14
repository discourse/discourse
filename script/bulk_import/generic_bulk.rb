# frozen_string_literal: true

require_relative "base"
require "sqlite3"
require "json"

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

    puts "running 'import:ensure_consistency' rake task."
    Rake::Task["import:ensure_consistency"].invoke
  end

  def execute
    import_categories
    import_users
    import_user_emails
    import_single_sign_on_records
    import_topics
    import_posts
    import_topic_allowed_users
    import_likes
    import_user_stats
    import_tags
  end

  def import_categories
    puts "Importing categories..."

    categories = query(<<~SQL)
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
        parent_category_id:
          row["parent_category_id"] ? category_id_from_imported_id(row["parent_category_id"]) : nil,
        slug: row["slug"],
      }
    end
  end

  def import_users
    puts "Importing users..."

    users = query(<<~SQL)
      SELECT ROWID, *
      FROM users
      ORDER BY ROWID
    SQL

    create_users(users) do |row|
      sso_record = JSON.parse(row["sso_record"]) if row["sso_record"].present?

      if row["suspension"].present?
        suspension = JSON.parse(row["suspension"])
        suspended_at = suspension["suspended_at"]
        suspended_till = suspension["suspended_till"]
      end

      {
        imported_id: row["id"],
        username: row["username"],
        name: row["name"],
        email: row["email"],
        external_id: sso_record&.fetch("external_id"),
        created_at: to_datetime(row["created_at"]),
        admin: row["admin"],
        moderator: row["moderator"],
        suspended_at: suspended_at,
        suspended_till: suspended_till,
      }
    end
  end

  def import_user_emails
    puts "", "Importing user emails..."

    users = query(<<~SQL)
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
        created_at: to_datetime(row["created_at"]),
      }
    end
  end

  def import_single_sign_on_records
    puts "", "Importing SSO records..."

    users = query(<<~SQL)
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

    topics = query(<<~SQL)
      SELECT ROWID, *
      FROM topics
      ORDER BY ROWID
    SQL

    create_topics(topics) do |row|
      {
        archetype: row["private_message"] ? Archetype.private_message : Archetype.default,
        imported_id: row["id"],
        title: row["title"],
        user_id: user_id_from_imported_id(row["user_id"]),
        created_at: to_datetime(row["created_at"]),
        category_id: category_id_from_imported_id(row["category_id"]),
        closed: to_boolean(row["closed"]),
        views: row["views"],
      }
    end
  end

  def import_topic_allowed_users
    puts "Importing topic_allowed_users..."

    topics = query(<<~SQL)
      SELECT ROWID, *
      FROM topics
      WHERE private_message IS NOT NULL
      ORDER BY ROWID
    SQL

    added = 0

    create_topic_allowed_users(topics) do |row|
      next unless topic_id = topic_id_from_imported_id(row["id"])
      imported_user_id = JSON.parse(row["private_message"])["user_ids"].first
      user_id = user_id_from_imported_id(imported_user_id)
      added += 1
      {
        # FIXME: missing imported_id
        topic_id: topic_id,
        user_id: user_id,
      }
    end

    puts "", "Added #{added} topic_allowed_users records."
  end

  def import_posts
    puts "Importing posts..."

    posts = query(<<~SQL)
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
        raw: row["raw"],
        like_count: row["like_count"],
      }
    end
  end

  def import_likes
    puts "Importing likes..."

    @imported_likes = Set.new

    likes = query(<<~SQL)
      SELECT ROWID, *
      FROM likes
      ORDER BY ROWID
    SQL

    create_post_actions(likes) do |row|
      post_id = post_id_from_imported_id(row["post_id"])
      user_id = user_id_from_imported_id(row["user_id"])

      next if post_id.nil? || user_id.nil?
      next if @imported_likes.add?([post_id, user_id]).nil?

      {
        # FIXME: missing imported_id
        post_id: post_id_from_imported_id(row["post_id"]),
        user_id: user_id_from_imported_id(row["user_id"]),
        post_action_type_id: 2,
        created_at: to_datetime(row["created_at"]),
      }
    end
  end

  def import_user_stats
    puts "Importing user stats..."

    users = query(<<~SQL)
      WITH posts_counts AS (
        SELECT COUNT(p.id) AS count, p.user_id
        FROM posts p GROUP BY p.user_id
      ),
      topic_counts AS (
        SELECT COUNT(t.id) AS count, t.user_id
        FROM topics t GROUP BY t.user_id
      ),
      first_post AS (
        SELECT MIN(p.created_at) AS created_at, p.user_id
        FROM posts p GROUP BY p.user_id ORDER BY p.created_at ASC
      )
      SELECT u.id AS user_id, u.created_at, pc.count AS posts, tc.count AS topics, fp.created_at AS first_post
      FROM users u
      JOIN posts_counts pc ON u.id = pc.user_id
      JOIN topic_counts tc ON u.id = tc.user_id
      JOIN first_post fp ON u.id = fp.user_id
    SQL

    create_user_stats(users) do |row|
      user = {
        imported_id: row["user_id"],
        imported_user_id: row["user_id"],
        new_since: to_datetime(row["created_at"]),
        post_count: row["posts"],
        topic_count: row["topics"],
        first_post_created_at: to_datetime(row["first_post"]),
      }

      likes_received = @db.execute(<<~SQL)
        SELECT COUNT(l.id) AS likes_received
        FROM likes l JOIN posts p ON l.post_id = p.id
        WHERE p.user_id = #{row["user_id"]}
      SQL

      user[:likes_received] = row["likes_received"] if likes_received

      likes_given = @db.execute(<<~SQL)
        SELECT COUNT(l.id) AS likes_given
        FROM likes l
        WHERE l.user_id = #{row["user_id"]}
      SQL

      user[:likes_given] = row["likes_given"] if likes_given

      user
    end
  end

  def import_tags
    puts "", "Importing tags..."

    tags =
      query("SELECT id as topic_id, tags FROM topics")
        .map do |r|
          next unless r["tags"]
          [r["topic_id"], JSON.parse(r["tags"]).uniq]
        end
        .compact

    tag_mapping = {}

    tags
      .map(&:last)
      .flatten
      .compact
      .uniq
      .each do |tag_name|
        cleaned_tag_name = DiscourseTagging.clean_tag(tag_name)
        tag = Tag.find_by_name(cleaned_tag_name) || Tag.create!(name: cleaned_tag_name)
        tag_mapping[tag_name] = tag.id
      end

    tags_disaggregated =
      tags
        .map do |topic_id, tags_of_topic|
          tags_of_topic.map { |t| { topic_id: topic_id, tag_id: tag_mapping.fetch(t) } }
        end
        .flatten

    create_topic_tags(tags_disaggregated) do |row|
      next unless topic_id = topic_id_from_imported_id(row[:topic_id])

      { topic_id: topic_id, tag_id: row[:tag_id] }
    end
  end

  def create_connection(path)
    sqlite = SQLite3::Database.new(path, results_as_hash: true)
    sqlite.busy_timeout = 60_000 # 60 seconds
    sqlite.auto_vacuum = "full"
    sqlite.foreign_keys = true
    sqlite.journal_mode = "wal"
    sqlite.synchronous = "normal"
    sqlite
  end

  def query(sql)
    @db.prepare(sql).execute
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

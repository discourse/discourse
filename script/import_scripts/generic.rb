# frozen_string_literal: true

require_relative 'base'
require 'sqlite3'

class ImportScripts::Generic < ImportScripts::Base
  BATCH_SIZE = 1000
  AVATAR_DIRECTORY = ENV["AVATAR_DIRECTORY"]
  UPLOAD_DIRECTORY = ENV["UPLOAD_DIRECTORY"]

  def initialize(db_path)
    super()
    @db = create_connection(db_path)
  end

  def execute
    import_users
    import_groups
    import_group_members
    import_categories
    import_topics
    import_posts
    mark_topics_as_solved
  end

  def import_users
    log_action "Creating users"
    total_count = count_users
    last_row_id = -1

    batches do |offset|
      rows, last_row_id = fetch_users(last_row_id)
      break if rows.empty?

      next if all_records_exist?(:users, rows.map { |row| row["id"] })

      create_users(rows, total: total_count, offset: offset) do |row|
        {
          id: row["id"],
          username: row["username"],
          created_at: to_datetime(row["created_at"]),
          name: row["name"],
          email: row["email"],
          last_seen_at: to_datetime(row[:"last_seen_at"]) || to_datetime(row["created_at"]),
          bio_raw: row["bio"],
          location: row["location"],
          admin: to_boolean(row["admin"]),
          moderator: to_boolean(row["moderator"]),
          post_create_action: proc do |user|
            create_avatar(user, row["avatar_path"])
            suspend_user(user, row["suspension"])
          end
        }
      end
    end
  end

  def create_avatar(user, avatar_path)
    return if avatar_path.blank?
    avatar_path = File.join(AVATAR_DIRECTORY, avatar_path)

    if File.exist?(avatar_path)
      @uploader.create_avatar(user, avatar_path)
    else
      STDERR.puts "Could not find avatar: #{avatar_path}"
    end
  end

  def suspend_user(user, suspension)
    return if suspension.blank?
    suspension = JSON.parse(suspension)

    user.suspended_at = suspension["suspended_at"] || user.last_seen_at || Time.now
    user.suspended_till = suspension["suspended_till"] || 200.years.from_now
    user.save!

    if suspension["reason"].present?
      StaffActionLogger.new(Discourse.system_user).log_user_suspend(user, suspension["reason"])
    end
  end

  def count_users
    @db.get_first_value(<<~SQL)
      SELECT COUNT(*)
      FROM users
    SQL
  end

  def fetch_users(last_row_id)
    query_with_last_rowid(<<~SQL, last_row_id)
      SELECT ROWID, *
      FROM users
      WHERE ROWID > :last_row_id
      ORDER BY ROWID
      LIMIT #{BATCH_SIZE}
    SQL
  end

  def import_groups
    log_action "Creating groups"
    rows = @db.execute(<<~SQL)
      SELECT *
      FROM groups
      ORDER BY ROWID
    SQL

    create_groups(rows) do |row|
      {
        id: row["id"],
        name: row["name"]
      }
    end
  end

  def import_group_members
    log_action "Adding group members"

    total_count = @db.get_first_value(<<~SQL)
      SELECT COUNT(*)
      FROM group_members
    SQL
    last_row_id = -1

    batches do |offset|
      rows, last_row_id = query_with_last_rowid(<<~SQL, last_row_id)
        SELECT ROWID, *
        FROM group_members
        WHERE ROWID > :last_row_id
        ORDER BY ROWID
        LIMIT #{BATCH_SIZE}
      SQL
      break if rows.empty?

      create_group_members(rows, total: total_count, offset: offset) do |row|
        {
          group_id: group_id_from_imported_group_id(row["group_id"]),
          user_id: user_id_from_imported_user_id(row["user_id"])
        }
      end
    end
  end

  def import_categories
    log_action "Creating categories"
    rows = @db.execute(<<~SQL)
      WITH RECURSIVE tree(id, parent_category_id, name, description, color, text_color, read_restricted, slug,
                          old_relative_url, level, rowid) AS (
          SELECT c.id, c.parent_category_id, c.name, c.description, c.color, c.text_color, c.read_restricted, c.slug,
                 c.old_relative_url, 0 AS level, c.ROWID
          FROM categories c
          WHERE c.parent_category_id IS NULL
          UNION
          SELECT c.id, c.parent_category_id, c.name, c.description, c.color, c.text_color, c.read_restricted, c.slug,
                 c.old_relative_url, tree.level + 1 AS level, c.ROWID
          FROM categories c,
               tree
          WHERE c.parent_category_id = tree.id
      )
      SELECT *
      FROM tree
      ORDER BY level, rowid
    SQL

    create_categories(rows) do |row|
      # TODO Add more columns
      {
        id: row["id"],
        name: row["name"],
        parent_category_id: category_id_from_imported_category_id(row["parent_category_id"]),
        post_create_action: proc do |category|
          create_permalink(row["old_relative_url"], category_id: category.id)
        end
      }
    end
  end

  def import_topics
    log_action "Creating topics"
    total_count = count_topics
    last_row_id = -1

    batches do |offset|
      rows, last_row_id = fetch_topics(last_row_id)
      break if rows.empty?

      next if all_records_exist?(:topics, rows.map { |row| row["id"] })

      create_posts(rows, total: total_count, offset: offset) do |row|
        # TODO add more columns
        mapped = {
          id: row["id"],
          title: row["title"],
          created_at: to_datetime(row["created_at"]),
          raw: process_raw(row),
          category: category_id_from_imported_category_id(row["category_id"]),
          user_id: user_id_from_imported_user_id(row["user_id"]) || Discourse::SYSTEM_USER_ID,
          post_create_action: proc do |post|
            add_tags(post, row["tags"])
            create_permalink(row["old_relative_url"], topic_id: post.topic.id)
          end
        }

        if row["private_message"].present?
          pm = JSON.parse(row["private_message"])
          target_usernames = ([row["user_id"]] + pm["user_ids"]).map { |id| find_user_by_import_id(id)&.username }
          target_group_names = pm["special_group_names"] + pm["group_ids"].map { |id| find_group_by_import_id(id)&.name }

          mapped[:archetype] = Archetype.private_message
          mapped[:target_usernames] = target_usernames.compact.uniq.join(",")
          mapped[:target_group_names] = target_group_names.compact.uniq.join(",")
        end

        mapped
      end
    end
  end

  def count_topics
    @db.get_first_value(<<~SQL)
      SELECT COUNT(*)
      FROM topics
    SQL
  end

  def fetch_topics(last_row_id)
    query_with_last_rowid(<<~SQL, last_row_id)
      SELECT ROWID, *
      FROM topics
      WHERE ROWID > :last_row_id
      ORDER BY ROWID
      LIMIT #{BATCH_SIZE}
    SQL
  end

  def process_raw(row)
    raw = row["raw"]
    upload_ids = row["upload_ids"]
    return raw if upload_ids.blank? || raw.blank?

    joined_upload_ids = JSON.parse(upload_ids).map { |id| SQLite3::Database.quote(id) }.join(",")
    files = @db.execute("SELECT * FROM uploads WHERE id IN (?)", joined_upload_ids)

    files.each do |file|
      user_id = user_id_from_imported_user_id(file["user_id"]) || Discourse::SYSTEM_USER_ID
      path = File.join(UPLOAD_DIRECTORY, file["path"])
      upload = create_upload(user_id, path, file["filename"])

      if upload.present? && upload.persisted?
        raw.gsub!("[upload|#{file['id']}]", @uploader.html_for_upload(upload, file["filename"]))
      end
    end

    raw
  end

  def add_tags(post, tags)
    tag_names = JSON.parse(tags) if tags
    DiscourseTagging.tag_topic_by_names(post.topic, staff_guardian, tag_names) if tag_names.present?
  end

  def create_permalink(url, topic_id: nil, post_id: nil, category_id: nil, tag_id: nil)
    return if url.blank? || Permalink.exists?(url: url)

    Permalink.create(
      url: url,
      topic_id: topic_id,
      post_id: post_id,
      category_id: category_id,
      tag_id: tag_id
    )
  end

  def import_posts
    log_action "Creating posts"
    total_count = count_posts
    last_row_id = -1

    batches do |offset|
      rows, last_row_id = fetch_posts(last_row_id)
      break if rows.empty?

      next if all_records_exist?(:posts, rows.map { |row| row["id"] })

      create_posts(rows, total: total_count, offset: offset) do |row|
        topic = topic_lookup_from_imported_post_id(row["topic_id"])
        next if !topic

        if row["small_action"]
          create_small_action(row, topic)
          next
        end

        reply_to = topic_lookup_from_imported_post_id(row["reply_to_post_id"]) if row["reply_to_post_id"]
        reply_to = nil if reply_to&.dig(:topic_id) != topic[:topic_id]

        mapped = {
          id: row["id"],
          topic_id: topic[:topic_id],
          created_at: to_datetime(row["created_at"]),
          raw: process_raw(row),
          reply_to_post_number: reply_to&.dig(:post_number),
          user_id: user_id_from_imported_user_id(row["user_id"]) || Discourse::SYSTEM_USER_ID,
          post_create_action: proc do |post|
            create_permalink(row["old_relative_url"], post_id: post.id)
          end
        }

        mapped[:post_type] = Post.types[:whisper] if to_boolean(row["whisper"])
        mapped[:custom_fields] = { is_accepted_answer: "true" } if to_boolean(row["accepted_answer"])
        mapped
      end
    end
  end

  def count_posts
    @db.get_first_value(<<~SQL)
      SELECT COUNT(*)
      FROM posts
    SQL
  end

  def fetch_posts(last_row_id)
    query_with_last_rowid(<<~SQL, last_row_id)
      SELECT ROWID, *
      FROM posts
      WHERE ROWID > :last_row_id
      ORDER BY ROWID
      LIMIT #{BATCH_SIZE}
    SQL
  end

  def mark_topics_as_solved
    log_action "Marking topics as solved..."

    DB.exec <<~SQL
      INSERT INTO topic_custom_fields (name, value, topic_id, created_at, updated_at)
      SELECT 'accepted_answer_post_id', pcf.post_id, p.topic_id, p.created_at, p.created_at
        FROM post_custom_fields pcf
        JOIN posts p ON p.id = pcf.post_id
       WHERE pcf.name = 'is_accepted_answer' AND pcf.value = 'true'
         AND NOT EXISTS (
           SELECT 1
           FROM topic_custom_fields x
           WHERE x.topic_id = p.topic_id AND x.name = 'accepted_answer_post_id'
         )
    SQL
  end

  def create_small_action(row, topic)
    small_action = JSON.parse(row["small_action"])

    case small_action["type"]
    when "split_topic"
      create_split_topic_small_action(row, small_action, topic)
    else
      raise "Unknown small action type: #{small_action['type']}"
    end
  end

  def create_split_topic_small_action(row, small_action, original_topic)
    destination_topic = topic_lookup_from_imported_post_id(small_action["destination_topic_id"])
    destination_topic = Topic.find_by(id: destination_topic[:topic_id]) if destination_topic
    return if !destination_topic

    original_topic = Topic.find_by(id: original_topic[:topic_id]) if original_topic
    return if !original_topic

    move_type = small_action['move_type']
    message = I18n.with_locale(SiteSetting.default_locale) do
      I18n.t(
        "move_posts.#{move_type}_moderator_post",
        count: small_action['post_count'],
        topic_link: "[#{destination_topic.title}](#{destination_topic.relative_url})"
      )
    end

    post_type = move_type.include?("message") ? Post.types[:whisper] : Post.types[:small_action]
    original_topic.add_moderator_post(
      Discourse.system_user, message,
      post_type: post_type,
      action_code: "split_topic",
      import_mode: true,
      created_at: to_datetime(row["created_at"]),
      custom_fields: { import_id: row["id"] }
    )
  end

  def query_with_last_rowid(sql, last_row_id)
    rows = @db.execute(sql, last_row_id: last_row_id)
    [rows, rows.last&.dig("rowid")]
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

  def log_action(text)
    puts "", text
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

  def batches
    super(BATCH_SIZE)
  end

  def staff_guardian
    @staff_guardian ||= Guardian.new(Discourse.system_user)
  end
end

ImportScripts::Generic.new(ARGV.first).perform

# frozen_string_literal: true

require_relative "base"
require "sqlite3"
require "json"

class BulkImport::Generic < BulkImport::Base
  AVATAR_DIRECTORY = ENV["AVATAR_DIRECTORY"]
  UPLOAD_DIRECTORY = ENV["UPLOAD_DIRECTORY"]

  def initialize(db_path, uploads_db_path = nil)
    super()
    @source_db = create_connection(db_path)
    @uploads_db = create_connection(uploads_db_path) if uploads_db_path
  end

  def start
    run # will call execute, and then "complete" the migration

    # Now that the migration is complete, do some more work:

    # Discourse::Application.load_tasks
    #
    # puts "running 'import:ensure_consistency' rake task."
    # Rake::Task["import:ensure_consistency"].invoke
  end

  def execute
    # import_categories
    import_users
    import_user_emails
    import_user_profiles
    import_user_options
    import_user_fields
    import_user_custom_field_values
    import_single_sign_on_records
    import_user_stats
    import_muted_users
    import_user_histories

    import_uploads
    import_user_avatars
    import_user_avatar_upload_references

    # import_topics
    # import_posts
    # import_topic_allowed_users
    # import_likes
    # import_tags

    @source_db.close
    @uploads_db.close if @uploads_db
  end

  def import_categories
    puts "Importing categories..."

    categories = query(<<~SQL)
      WITH RECURSIVE tree(id, parent_category_id, name, description, color, text_color, read_restricted, slug,
                          old_relative_url, existing_id, level) AS (
          SELECT c.id, c.parent_category_id, c.name, c.description, c.color, c.text_color, c.read_restricted, c.slug,
                 c.old_relative_url, c.existing_id, 0 AS level
          FROM categories c
          WHERE c.parent_category_id IS NULL
          UNION
          SELECT c.id, c.parent_category_id, c.name, c.description, c.color, c.text_color, c.read_restricted, c.slug,
                 c.old_relative_url, c.existing_id, tree.level + 1 AS level
          FROM categories c,
               tree
          WHERE c.parent_category_id = tree.id
      )
      SELECT *
      FROM tree
      ORDER BY level, id
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

      categories.close
    end
  end

  def import_users
    puts "Importing users..."

    users = query(<<~SQL)
      SELECT *
      FROM users
      ORDER BY id
    SQL

    create_users(users) do |row|
      next if user_id_from_imported_id(row["id"]).present?

      sso_record = JSON.parse(row["sso_record"]) if row["sso_record"].present?

      if row["suspension"].present?
        suspension = JSON.parse(row["suspension"])
        suspended_at = suspension["suspended_at"]
        suspended_till = suspension["suspended_till"]
      end

      if row["anonymized"] == 1
        while true
          anon_suffix = (SecureRandom.random_number * 100_000_000).to_i
          break if !@anonymized_user_suffixes.include?(anon_suffix)
        end

        row["username"] = "anon_#{anon_suffix}"
        row["email"] = "#{row["username"]}#{UserAnonymizer::EMAIL_SUFFIX}"
        row["name"] = nil
        row["registration_ip_address"] = nil

        @anonymized_user_suffixes << anon_suffix
      end

      {
        imported_id: row["id"],
        username: row["username"],
        original_username: row["original_username"],
        name: row["name"],
        email: row["email"],
        external_id: sso_record&.fetch("external_id"),
        created_at: to_datetime(row["created_at"]),
        last_seen_at: to_datetime(row["last_seen_at"]),
        admin: row["admin"],
        moderator: row["moderator"],
        suspended_at: suspended_at,
        suspended_till: suspended_till,
        registration_ip_address: row["registration_ip_address"],
      }
    end

    users.close
  end

  def import_user_emails
    puts "", "Importing user emails..."

    existing_user_ids = UserEmail.pluck(:user_id).to_set

    users = query(<<~SQL)
      SELECT id, email, created_at
      FROM users
      ORDER BY id
    SQL

    create_user_emails(users) do |row|
      user_id = user_id_from_imported_id(row["id"])
      next if user_id && existing_user_ids.include?(user_id)

      { user_id: user_id, email: row["email"], created_at: to_datetime(row["created_at"]) }
    end

    users.close
  end

  def import_user_profiles
    puts "", "Importing user profiles..."

    users = query(<<~SQL)
      SELECT id, bio
      FROM users
      WHERE bio IS NOT NULL
      ORDER BY id
    SQL

    existing_user_ids = UserProfile.pluck(:user_id).to_set

    create_user_profiles(users) do |row|
      user_id = user_id_from_imported_id(row["id"])
      next if user_id && existing_user_ids.include?(user_id)

      { user_id: user_id, bio_raw: row["bio"] }
    end

    users.close
  end

  def import_user_options
    puts "", "Importing user options..."

    users = query(<<~SQL)
      SELECT id, timezone
      FROM users
      WHERE timezone IS NOT NULL
      ORDER BY id
    SQL

    existing_user_ids = UserOption.pluck(:user_id).to_set

    create_user_options(users) do |row|
      user_id = user_id_from_imported_id(row["id"])
      next if user_id && existing_user_ids.include?(user_id)

      { user_id: user_id, timezone: row["timezone"] }
    end

    users.close
  end

  def import_user_fields
    puts "", "Importing user fields..."

    user_fields = query(<<~SQL)
      SELECT *
      FROM user_fields
      ORDER BY ROWID
    SQL

    existing_user_field_names = UserField.pluck(:name).to_set

    user_fields.each do |row|
      next if existing_user_field_names.include?(row["name"])

      options = row.delete("options")
      field = UserField.create!(row)

      if options.present?
        JSON.parse(options).each { |option| field.user_field_options.create!(value: option) }
      end
    end

    user_fields.close
  end

  def import_user_custom_field_values
    puts "", "Importing user custom field values..."

    discourse_field_mapping = UserField.pluck(:name, :id).to_h

    user_fields = query("SELECT id, name FROM user_fields")

    field_id_mapping =
      user_fields
        .map do |row|
          discourse_field_id = discourse_field_mapping[row["name"]]
          field_name = "#{User::USER_FIELD_PREFIX}#{discourse_field_id}"
          [row["id"], field_name]
        end
        .to_h

    user_fields.close

    values = query(<<~SQL)
      SELECT v.*
        FROM user_custom_field_values v
             JOIN users u ON v.user_id = u.id
       WHERE u.anonymized = FALSE
    SQL

    existing_user_fields =
      UserCustomField.pluck(:user_id, :name).map { |id, name| "#{id}-#{name}" }.to_set

    create_user_custom_fields(values) do |row|
      user_id = user_id_from_imported_id(row["user_id"])
      field_name = field_id_mapping[row["field_id"]]
      next if user_id && field_name && existing_user_fields.include?("#{user_id}-#{field_name}")

      { user_id: user_id, name: field_name, value: row["value"] }
    end

    values.close
  end

  def import_single_sign_on_records
    puts "", "Importing SSO records..."

    users = query(<<~SQL)
      SELECT id, sso_record
      FROM users
      WHERE sso_record IS NOT NULL
      ORDER BY id
    SQL

    existing_user_ids = SingleSignOnRecord.pluck(:user_id).to_set

    create_single_sign_on_records(users) do |row|
      user_id = user_id_from_imported_id(row["id"])
      next if user_id && existing_user_ids.include?(user_id)

      sso_record = JSON.parse(row["sso_record"], symbolize_names: true)
      sso_record[:user_id] = user_id
      sso_record
    end

    users.close
  end

  def import_topics
    puts "Importing topics..."

    topics = query(<<~SQL)
      SELECT *
      FROM topics
      ORDER BY id
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

    topics.close
  end

  def import_topic_allowed_users
    puts "Importing topic_allowed_users..."

    topics = query(<<~SQL)
      SELECT *
      FROM topics
      WHERE private_message IS NOT NULL
      ORDER BY id
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

    topics.close

    puts "", "Added #{added} topic_allowed_users records."
  end

  def import_posts
    puts "Importing posts..."

    posts = query(<<~SQL)
      SELECT *
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
        reply_to_post_number:
          row["reply_to_post_id"] ? post_number_from_imported_id(row["reply_to_post_id"]) : nil,
      }
    end

    posts.close
  end

  def process_raw(original_raw)
    original_raw
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

    likes.close
  end

  def import_user_stats
    puts "Importing user stats..."

    start_time = Time.now

    # TODO Add likes received and likes given from `post_actions` table

    DB.exec(<<~SQL)
        WITH
          posts_counts AS (
            SELECT COUNT(p.id) AS count, p.user_id FROM posts p GROUP BY p.user_id
          ),
          topic_counts AS (
            SELECT COUNT(t.id) AS count, t.user_id FROM topics t GROUP BY t.user_id
          ),
          first_post AS (
            SELECT MIN(p.created_at) AS created_at, p.user_id FROM posts p GROUP BY p.user_id
          )
      INSERT
        INTO user_stats (user_id, new_since, post_count, topic_count, first_post_created_at)
      SELECT u.id, u.created_at AS new_since, COALESCE(pc.count, 0) AS post_count, COALESCE(tc.count, 0) AS topic_count,
             fp.created_at AS first_post_created_at
        FROM users u
             LEFT JOIN posts_counts pc ON u.id = pc.user_id
             LEFT JOIN topic_counts tc ON u.id = tc.user_id
             LEFT JOIN first_post fp ON u.id = fp.user_id
       WHERE NOT EXISTS (
         SELECT 1
           FROM user_stats us
          WHERE us.user_id = u.id
       )
          ON CONFLICT DO NOTHING
    SQL

    puts "  Imported user stats in #{Time.now - start_time} seconds."

    # likes_received = @db.execute(<<~SQL)
    #   SELECT COUNT(l.id) AS likes_received
    #   FROM likes l JOIN posts p ON l.post_id = p.id
    #   WHERE p.user_id = #{row["user_id"]}
    # SQL
    #
    # user[:likes_received] = row["likes_received"] if likes_received
    #
    # likes_given = @db.execute(<<~SQL)
    #   SELECT COUNT(l.id) AS likes_given
    #   FROM likes l
    #   WHERE l.user_id = #{row["user_id"]}
    # SQL
    #
    # user[:likes_given] = row["likes_given"] if likes_given
  end

  def import_muted_users
    puts "Importing muted users..."

    muted_users = query(<<~SQL)
      SELECT *
        FROM muted_users
    SQL

    existing_user_ids = MutedUser.pluck(:user_id).to_set

    create_muted_users(muted_users) do |row|
      user_id = user_id_from_imported_id(row["user_id"])
      next if user_id && existing_user_ids.include?(user_id)

      { user_id: user_id, muted_user_id: user_id_from_imported_id(row["muted_user_id"]) }
    end

    muted_users.close
  end

  def import_user_histories
    puts "Importing user histories..."

    user_histories = query(<<~SQL)
      SELECT id, JSON_EXTRACT(suspension, '$.reason') AS reason
        FROM users
       WHERE suspension IS NOT NULL
    SQL

    action_id = UserHistory.actions[:suspend_user]
    existing_user_ids = UserHistory.where(action: action_id).pluck(:target_user_id).to_set

    create_user_histories(user_histories) do |row|
      user_id = user_id_from_imported_id(row["id"])
      next if user_id && existing_user_ids.include?(user_id)

      {
        action: action_id,
        acting_user_id: Discourse::SYSTEM_USER_ID,
        target_user_id: user_id,
        details: row["reason"],
      }
    end

    user_histories.close
  end

  def import_uploads
    return if !@uploads_db

    puts "Importing uploads..."

    uploads = query(<<~SQL, db: @uploads_db)
      SELECT id, upload
        FROM uploads
       ORDER BY id
    SQL

    create_uploads(uploads) do |row|
      next if upload_id_from_original_id(row["id"]).present?

      upload = JSON.parse(row["upload"], symbolize_names: true)
      upload[:original_id] = row["id"]
      upload
    end

    uploads.close
  end

  def import_user_avatars
    return if !@uploads_db

    puts "Importing user avatars..."

    avatars = query(<<~SQL)
      SELECT id, avatar_upload_id
        FROM users
       WHERE avatar_upload_id
       ORDER BY id
    SQL

    existing_user_ids = UserAvatar.pluck(:user_id).to_set

    create_user_avatars(avatars) do |row|
      user_id = user_id_from_imported_id(row["id"])
      upload_id = upload_id_from_original_id(row["avatar_upload_id"])
      next if !upload_id || !user_id || existing_user_ids.include?(user_id)

      { user_id: user_id, custom_upload_id: upload_id }
    end

    avatars.close
  end

  def import_user_avatar_upload_references
    puts "Importing upload references for user avatars..."

    start_time = Time.now

    DB.exec(<<~SQL)
      INSERT INTO upload_references (upload_id, target_type, target_id, created_at, updated_at)
      SELECT ua.custom_upload_id, 'UserAvatar', ua.id, ua.created_at, ua.updated_at
        FROM user_avatars ua
       WHERE ua.custom_upload_id IS NOT NULL
         AND NOT EXISTS (
         SELECT 1
           FROM upload_references ur
          WHERE ur.upload_id = ua.custom_upload_id
            AND ur.target_type = 'UserAvatar'
            AND ur.target_id = ua.id
       )
          ON CONFLICT DO NOTHING
    SQL

    puts "  Imported upload references in #{Time.now - start_time} seconds."
  end

  def import_tags
    puts "", "Importing tags..."

    topics = query("SELECT id as topic_id, tags FROM topics")

    tags =
      topics
        .map do |r|
          next unless r["tags"]
          [r["topic_id"], JSON.parse(r["tags"]).uniq]
        end
        .compact

    topics.close

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
    sqlite.journal_mode = "wal"
    sqlite.synchronous = "normal"
    sqlite
  end

  def query(sql, db: @source_db)
    db.prepare(sql).execute
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

BulkImport::Generic.new(ARGV[0], ARGV[1]).start

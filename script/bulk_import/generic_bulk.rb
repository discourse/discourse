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
    import_uploads

    # needs to happen before users, because keeping group names is more important than usernames
    import_groups

    import_users
    import_user_emails
    import_user_profiles
    import_user_options
    import_user_fields
    import_user_custom_field_values
    import_single_sign_on_records
    import_muted_users
    import_user_histories

    import_user_avatars
    update_uploaded_avatar_id

    import_group_members

    import_tag_groups
    import_tags

    import_categories
    import_category_tag_groups
    import_category_permissions

    import_topics
    import_posts

    import_topic_tags
    import_topic_allowed_users

    import_likes
    import_votes
    import_answers

    import_upload_references
    import_user_stats
    enable_category_settings

    @source_db.close
    @uploads_db.close if @uploads_db
  end

  def import_categories
    puts "", "Importing categories..."

    categories = query(<<~SQL)
        WITH
          RECURSIVE
          tree AS (
                    SELECT c.id, c.parent_category_id, c.name, c.description, c.color, c.text_color, c.read_restricted,
                           c.slug, c.old_relative_url, c.existing_id, c.position, c.logo_upload_id, 0 AS level
                      FROM categories c
                     WHERE c.parent_category_id IS NULL
                     UNION ALL
                    SELECT c.id, c.parent_category_id, c.name, c.description, c.color, c.text_color, c.read_restricted,
                           c.slug, c.old_relative_url, c.existing_id, c.position, c.logo_upload_id, tree.level + 1 AS level
                      FROM categories c,
                           tree
                     WHERE c.parent_category_id = tree.id
                  )
      SELECT *
        FROM tree
       ORDER BY level, position, id
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
        read_restricted: row["read_restricted"],
        uploaded_logo_id:
          row["logo_upload_id"] ? upload_id_from_original_id(row["logo_upload_id"]) : nil,
      }
    end

    categories.close
  end

  def import_category_tag_groups
    puts "", "Importing category tag groups..."

    category_tag_groups = query(<<~SQL)
      SELECT c.id AS category_id, t.value AS tag_group_id
        FROM categories c,
             JSON_EACH(c.tag_group_ids) t
       ORDER BY category_id, tag_group_id
    SQL

    existing_category_tag_groups = CategoryTagGroup.pluck(:category_id, :tag_group_id).to_set

    create_category_tag_groups(category_tag_groups) do |row|
      category_id = category_id_from_imported_id(row["category_id"])
      tag_group_id = @tag_group_mapping[row["tag_group_id"]]

      next unless category_id && tag_group_id
      next unless existing_category_tag_groups.add?([category_id, tag_group_id])

      { category_id: category_id, tag_group_id: tag_group_id }
    end

    category_tag_groups.close
  end

  def import_category_permissions
    puts "", "Importing category permissions..."

    permissions = query(<<~SQL)
      SELECT c.id AS category_id, p.value -> 'group_id' AS group_id, p.value -> 'permission_type' AS permission_type
        FROM categories c,
             JSON_EACH(c.permissions) p
    SQL

    existing_category_group_ids = CategoryGroup.pluck(:category_id, :group_id).to_set

    create_category_groups(permissions) do |row|
      category_id = category_id_from_imported_id(row["category_id"])
      group_id = group_id_from_imported_id(row["group_id"])
      next if existing_category_group_ids.include?([category_id, group_id])

      { category_id: category_id, group_id: group_id, permission_type: row["permission_type"] }
    end

    permissions.close
  end

  def import_groups
    puts "", "Importing groups..."

    groups = query(<<~SQL)
      SELECT *
      FROM groups
      ORDER BY id
    SQL

    create_groups(groups) do |row|
      next if group_id_from_imported_id(row["id"]).present?

      {
        imported_id: row["id"],
        name: row["name"],
        full_name: row["full_name"],
        visibility_level: row["visibility_level"],
        members_visibility_level: row["members_visibility_level"],
        mentionable_level: row["mentionable_level"],
        messageable_level: row["messageable_level"],
      }
    end

    groups.close
  end

  def import_group_members
    puts "", "Importing group members..."

    group_members = query(<<~SQL)
      SELECT *
      FROM group_members
      ORDER BY ROWID
    SQL

    existing_group_user_ids = GroupUser.pluck(:group_id, :user_id).to_set

    create_group_users(group_members) do |row|
      group_id = group_id_from_imported_id(row["group_id"])
      user_id = user_id_from_imported_id(row["user_id"])
      next if existing_group_user_ids.include?([group_id, user_id])

      { group_id: group_id, user_id: user_id }
    end

    group_members.close
  end

  def import_users
    puts "", "Importing users..."

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

      # TODO Update email settings before go-live
      {
        user_id: user_id,
        timezone: row["timezone"],
        email_level: UserOption.email_level_types[:never],
        email_messages_level: UserOption.email_level_types[:never],
        email_digests: false,
      }
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
      UserCustomField.where("name LIKE '#{User::USER_FIELD_PREFIX}%'").pluck(:user_id, :name).to_set

    create_user_custom_fields(values) do |row|
      user_id = user_id_from_imported_id(row["user_id"])
      field_name = field_id_mapping[row["field_id"]]
      next if user_id && field_name && existing_user_fields.include?([user_id, field_name])

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
    puts "", "Importing topics..."

    topics = query(<<~SQL)
      SELECT *
      FROM topics
      ORDER BY id
    SQL

    create_topics(topics) do |row|
      unless row["category_id"] && (category_id = category_id_from_imported_id(row["category_id"]))
        next
      end

      {
        archetype: row["private_message"] ? Archetype.private_message : Archetype.default,
        imported_id: row["id"],
        title: row["title"],
        user_id: user_id_from_imported_id(row["user_id"]),
        created_at: to_datetime(row["created_at"]),
        category_id: category_id,
        closed: to_boolean(row["closed"]),
        views: row["views"],
        subtype: "question_answer", # TODO Make this configurable!!
      }
    end

    topics.close
  end

  def import_topic_allowed_users
    puts "", "Importing topic_allowed_users..."

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

    puts "  Added #{added} topic_allowed_users records."
  end

  def import_posts
    puts "", "Importing posts..."

    posts = query(<<~SQL)
      SELECT *
      FROM posts
      ORDER BY topic_id, id
    SQL

    group_names = Group.pluck(:id, :name).to_h

    create_posts(posts) do |row|
      next if row["raw"].blank?
      next unless (topic_id = topic_id_from_imported_id(row["topic_id"]))
      next if post_id_from_imported_id(row["id"]).present?

      # TODO Ensure that we calculate the `like_count` if the column is empty, but the DB contains likes.
      # Otherwise #import_user_stats will not be able to calculate the correct `likes_received` value.

      raw = row["raw"]

      if row["mentions"].present?
        mentions = JSON.parse(row["mentions"])

        # TODO Implement mentions for types other than groups

        mentions.each do |mention|
          group_id = group_id_from_imported_id(mention["id"])
          group_name = group_names[group_id]
          puts "group not found -- #{mention["id"]}" unless group_name
          raw.gsub!(mention["placeholder"], "@#{group_name}")
        end
      end

      {
        imported_id: row["id"],
        topic_id: topic_id,
        user_id: user_id_from_imported_id(row["user_id"]),
        created_at: to_datetime(row["created_at"]),
        raw: raw,
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
    puts "", "Importing likes..."

    likes = query(<<~SQL)
      SELECT post_id, user_id, created_at
        FROM likes
       ORDER BY post_id, user_id
    SQL

    post_action_type_id = PostActionType.types[:like]
    existing_likes =
      PostAction.where(post_action_type_id: post_action_type_id).pluck(:post_id, :user_id).to_set

    create_post_actions(likes) do |row|
      post_id = post_id_from_imported_id(row["post_id"])
      user_id = user_id_from_imported_id(row["user_id"])

      next unless post_id && user_id
      next unless existing_likes.add?([post_id, user_id])

      {
        post_id: post_id,
        user_id: user_id,
        post_action_type_id: post_action_type_id,
        created_at: to_datetime(row["created_at"]),
      }
    end

    likes.close

    puts "", "Updating like counts of topics..."
    start_time = Time.now

    DB.exec(<<~SQL)
        WITH
          likes AS (
                     SELECT topic_id, SUM(like_count) AS like_count FROM posts WHERE like_count > 0 GROUP BY topic_id
                   )
      UPDATE topics
         SET like_count = likes.like_count
        FROM likes
       WHERE topics.id = likes.topic_id
         AND topics.like_count <> likes.like_count
    SQL

    puts "  Update took #{(Time.now - start_time).to_i} seconds."
  end

  def import_user_stats
    puts "", "Importing user stats..."

    start_time = Time.now

    # TODO Merge with #update_user_stats from import.rake and check if there are privacy concerns wi
    # E.g. maybe we need to exclude PMs from the calculation?

    DB.exec(<<~SQL)
        WITH
          post_stats AS (
                          SELECT p.user_id, COUNT(p.id) AS post_count, MIN(p.created_at) AS first_post_created_at,
                                 SUM(like_count) AS likes_received
                            FROM posts p
                           GROUP BY p.user_id
                        ),
          topic_stats AS (
                           SELECT t.user_id, COUNT(t.id) AS topic_count FROM topics t GROUP BY t.user_id
                         ),
          like_stats AS (
                          SELECT pa.user_id, COUNT(*) AS likes_given
                            FROM post_actions pa
                           WHERE pa.post_action_type_id = 2
                           GROUP BY pa.user_id
                        )
      INSERT
        INTO user_stats (user_id, new_since, post_count, topic_count, first_post_created_at, likes_received, likes_given)
      SELECT u.id, u.created_at AS new_since, COALESCE(ps.post_count, 0) AS post_count,
             COALESCE(ts.topic_count, 0) AS topic_count, ps.first_post_created_at,
             COALESCE(ps.likes_received, 0) AS likes_received, COALESCE(ls.likes_given, 0) AS likes_given
        FROM users u
             LEFT JOIN post_stats ps ON u.id = ps.user_id
             LEFT JOIN topic_stats ts ON u.id = ts.user_id
             LEFT JOIN like_stats ls ON u.id = ls.user_id
       WHERE NOT EXISTS (
                          SELECT 1
                            FROM user_stats us
                           WHERE us.user_id = u.id
                        )
          ON CONFLICT DO NOTHING
    SQL

    puts "  Imported user stats in #{(Time.now - start_time).to_i} seconds."
  end

  def import_muted_users
    puts "", "Importing muted users..."

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
    puts "", "Importing user histories..."

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

    puts "", "Importing uploads..."

    uploads = query(<<~SQL, db: @uploads_db)
      SELECT id, upload
        FROM uploads
       WHERE upload IS NOT NULL
       ORDER BY rowid
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

    puts "", "Importing user avatars..."

    avatars = query(<<~SQL)
      SELECT id, avatar_upload_id
        FROM users
       WHERE avatar_upload_id IS NOT NULL
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

  def import_upload_references
    puts "", "Importing upload references for user avatars..."
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
    puts "  Import took #{(Time.now - start_time).to_i} seconds."

    puts "", "Importing upload references for categories..."
    start_time = Time.now
    DB.exec(<<~SQL)
      INSERT INTO upload_references (upload_id, target_type, target_id, created_at, updated_at)
      SELECT upload_id, 'Category', target_id, created_at, updated_at
        FROM (
               SELECT uploaded_logo_id AS upload_id, id AS target_id, created_at, updated_at
                 FROM categories
                WHERE uploaded_logo_id IS NOT NULL
                UNION
               SELECT uploaded_logo_dark_id AS upload_id, id AS target_id, created_at, updated_at
                 FROM categories
                WHERE uploaded_logo_dark_id IS NOT NULL
                UNION
               SELECT uploaded_background_id AS upload_id, id AS target_id, created_at, updated_at
                 FROM categories
                WHERE uploaded_background_id IS NOT NULL
             ) x
       WHERE NOT EXISTS (
                          SELECT 1
                            FROM upload_references ur
                           WHERE ur.upload_id = x.upload_id
                             AND ur.target_type = 'Category'
                             AND ur.target_id = x.target_id
                        )
          ON CONFLICT DO NOTHING
    SQL
    puts "  Import took #{(Time.now - start_time).to_i} seconds."

    puts "", "Importing upload references for posts..."
    post_uploads = query(<<~SQL)
      SELECT p.id AS post_id, u.value AS upload_id
        FROM posts p,
             JSON_EACH(p.upload_ids) u
       WHERE upload_ids IS NOT NULL
    SQL

    existing_upload_references =
      UploadReference.where(target_type: "Post").pluck(:upload_id, :target_id).to_set

    create_upload_references(post_uploads) do |row|
      upload_id = upload_id_from_original_id(row["upload_id"])
      post_id = post_id_from_imported_id(row["post_id"])

      next unless upload_id && post_id
      next unless existing_upload_references.add?([upload_id, post_id])

      { upload_id: upload_id, target_type: "Post", target_id: post_id }
    end

    post_uploads.close
  end

  def update_uploaded_avatar_id
    puts "", "Updating user's uploaded_avatar_id column..."

    start_time = Time.now

    DB.exec(<<~SQL)
      UPDATE users u
         SET uploaded_avatar_id = ua.custom_upload_id
        FROM user_avatars ua
       WHERE u.uploaded_avatar_id IS NULL
         AND u.id = ua.user_id
         AND ua.custom_upload_id IS NOT NULL
    SQL

    puts "  Update took #{(Time.now - start_time).to_i} seconds."
  end

  def import_tag_groups
    puts "", "Importing tag groups..."

    SiteSetting.tags_listed_by_group = true

    @tag_group_mapping = {}

    tag_groups = query(<<~SQL)
      SELECT *
        FROM tag_groups
       ORDER BY id
    SQL

    tag_groups.each do |row|
      tag_group = TagGroup.find_or_create_by(name: row["name"])
      @tag_group_mapping[row["id"]] = tag_group.id
    end

    tag_groups.close
  end

  def import_tags
    puts "", "Importing tags..."

    SiteSetting.max_tag_length = 100 if SiteSetting.max_tag_length < 100

    @tag_mapping = {}

    tags = query(<<~SQL)
      SELECT *
        FROM tags
       ORDER BY id
    SQL

    tags.each do |row|
      cleaned_tag_name = DiscourseTagging.clean_tag(row["name"])
      tag = Tag.find_or_create_by(name: cleaned_tag_name)
      @tag_mapping[row["id"]] = tag.id

      if row["tag_group_id"]
        TagGroupMembership.find_or_create_by(
          tag_id: tag.id,
          tag_group_id: @tag_group_mapping[row["tag_group_id"]],
        )
      end
    end

    tags.close
  end

  def import_topic_tags
    puts "", "Importing topic tags..."

    topic_tags = query(<<~SQL)
      SELECT *
        FROM topic_tags
       ORDER BY topic_id, tag_id
    SQL

    existing_topic_tags = TopicTag.pluck(:topic_id, :tag_id).to_set

    create_topic_tags(topic_tags) do |row|
      topic_id = topic_id_from_imported_id(row["topic_id"])
      tag_id = @tag_mapping[row["tag_id"]]

      next unless topic_id && tag_id
      next unless existing_topic_tags.add?([topic_id, tag_id])

      { topic_id: topic_id, tag_id: tag_id }
    end

    topic_tags.close
  end

  def import_votes
    puts "", "Importing votes for posts..."

    votes = query(<<~SQL)
      SELECT *
        FROM votes
       WHERE votable_type = 'Post'
    SQL

    votable_type = "Post"
    existing_votes =
      QuestionAnswerVote.where(votable_type: votable_type).pluck(:user_id, :votable_id).to_set

    create_question_answer_votes(votes) do |row|
      user_id = user_id_from_imported_id(row["user_id"])
      post_id = post_id_from_imported_id(row["votable_id"])

      next unless user_id && post_id
      next unless existing_votes.add?([user_id, post_id])

      {
        user_id: user_id,
        direction: row["direction"],
        votable_type: votable_type,
        votable_id: post_id,
        created_at: to_datetime(row["created_at"]),
      }
    end

    votes.close

    puts "", "Updating vote counts of posts..."

    start_time = Time.now

    DB.exec(<<~SQL)
        WITH
          votes AS (
                     SELECT votable_id AS post_id, SUM(CASE direction WHEN 'up' THEN 1 ELSE -1 END) AS vote_count
                       FROM question_answer_votes
                      GROUP BY votable_id
                   )
      UPDATE posts
         SET qa_vote_count = votes.vote_count
        FROM votes
       WHERE votes.post_id = posts.id
         AND votes.vote_count <> posts.qa_vote_count
    SQL

    puts "  Update took #{(Time.now - start_time).to_i} seconds."
  end

  def import_answers
    puts "", "Importing solutions into post custom fields..."

    solutions = query(<<~SQL)
      SELECT *
        FROM solutions
       ORDER BY topic_id
    SQL

    field_name = "is_accepted_answer"
    value = "true"
    existing_fields = PostCustomField.where(name: field_name).pluck(:post_id).to_set

    create_post_custom_fields(solutions) do |row|
      next unless (post_id = post_id_from_imported_id(row["post_id"]))
      next unless existing_fields.add?(post_id)

      {
        post_id: post_id,
        name: field_name,
        value: value,
        created_at: to_datetime(row["created_at"]),
      }
    end

    puts "", "Importing solutions into topic custom fields..."

    solutions.reset

    field_name = "accepted_answer_post_id"
    existing_fields = TopicCustomField.where(name: field_name).pluck(:topic_id).to_set

    create_topic_custom_fields(solutions) do |row|
      post_id = post_id_from_imported_id(row["post_id"])
      topic_id = topic_id_from_imported_id(row["topic_id"])

      next unless post_id && topic_id
      next unless existing_fields.add?(topic_id)

      {
        topic_id: topic_id,
        name: field_name,
        value: post_id.to_s,
        created_at: to_datetime(row["created_at"]),
      }
    end

    puts "", "Importing solutions into user actions..."

    existing_fields = nil
    solutions.reset

    action_type = UserAction::SOLVED
    existing_actions = UserAction.where(action_type: action_type).pluck(:target_post_id).to_set

    create_user_actions(solutions) do |row|
      post_id = post_id_from_imported_id(row["post_id"])
      next unless post_id && existing_actions.add?(post_id)

      topic_id = topic_id_from_imported_id(row["topic_id"])
      user_id = user_id_from_imported_id(row["user_id"])
      next unless topic_id && user_id

      acting_user_id = row["acting_user_id"] ? user_id_from_imported_id(row["acting_user_id"]) : nil

      {
        action_type: action_type,
        user_id: user_id,
        target_topic_id: topic_id,
        target_post_id: post_id,
        acting_user_id: acting_user_id || Discourse::SYSTEM_USER_ID,
      }
    end

    solutions.close
  end

  def enable_category_settings
    puts "", "Updating category settings..."

    start_time = Time.now

    DB.exec(<<~SQL)
      INSERT INTO category_custom_fields (category_id, name, value, created_at, updated_at)
      SELECT c.id, s.name, s.value, NOW(), NOW()
        FROM categories c,
             (
               VALUES ('create_as_post_voting_default', 'true'), ('enable_accepted_answers', 'true')
             ) AS s (name, value)
       WHERE NOT EXISTS (
                          SELECT 1 FROM category_custom_fields x WHERE x.category_id = c.id AND x.name = s.name
                        )
    SQL

    puts "  Update took #{(Time.now - start_time).to_i} seconds."
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

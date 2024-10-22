# frozen_string_literal: true

begin
  require_relative "base"
  require "sqlite3"
  require "json"
rescue LoadError
  STDERR.puts "",
              "ERROR: Failed to load required gems.",
              "",
              "You need to enable the `generic_import` group in your Gemfile.",
              "Execute the following command to do so:",
              "",
              "\tbundle config set --local with generic_import && bundle install",
              ""
  exit 1
end

class BulkImport::Generic < BulkImport::Base
  AVATAR_DIRECTORY = ENV["AVATAR_DIRECTORY"]
  UPLOAD_DIRECTORY = ENV["UPLOAD_DIRECTORY"]
  CONTENT_UPLOAD_REFERENCE_TYPES = %w[posts chat_messages]
  LAST_VIEWED_AT_PLACEHOLDER = "1970-01-01 00:00:00"

  def initialize(db_path, uploads_db_path = nil)
    super()
    @source_db = create_connection(db_path)
    @uploads_db = create_connection(uploads_db_path) if uploads_db_path
  end

  def start
    run # will call execute, and then "complete" the migration

    # Now that the migration is complete, do some more work:

    ENV["SKIP_USER_STATS"] = "1"
    Discourse::Application.load_tasks

    puts "running 'import:ensure_consistency' rake task."
    Rake::Task["import:ensure_consistency"].invoke
  end

  def execute
    enable_required_plugins
    import_site_settings

    import_uploads

    # needs to happen before users, because keeping group names is more important than usernames
    import_groups

    import_users
    import_user_emails
    import_user_profiles
    import_user_options
    import_user_fields
    import_user_field_values
    import_single_sign_on_records
    import_user_associated_accounts
    import_muted_users
    import_user_histories
    import_user_notes
    import_user_note_counts
    import_user_followers
    import_user_custom_fields
    update_user_signatures

    import_user_avatars
    update_uploaded_avatar_id

    import_group_members

    import_tag_groups
    import_tags
    import_tag_users

    import_categories
    import_category_custom_fields
    import_category_tag_groups
    import_category_permissions
    import_category_users

    import_topics
    import_posts
    import_topic_custom_fields
    import_post_custom_fields

    import_polls
    import_poll_options
    import_poll_votes

    import_topic_tags
    import_topic_allowed_users
    import_topic_allowed_groups

    import_likes
    import_votes
    import_answers
    import_gamification_scores
    import_post_events

    import_badge_groupings
    import_badges
    import_user_badges

    import_optimized_images

    import_topic_users
    update_topic_users

    import_user_stats

    import_permalink_normalizations
    import_permalinks

    import_chat_direct_messages
    import_chat_channels

    import_chat_threads
    import_chat_messages

    import_user_chat_channel_memberships
    import_chat_thread_users

    import_chat_reactions
    import_chat_mentions

    update_chat_threads
    update_chat_membership_metadata

    import_upload_references
  end

  def execute_after
    import_category_about_topics

    @source_db.close
    @uploads_db.close if @uploads_db
  end

  def enable_required_plugins
    puts "", "Enabling required plugins..."

    required_plugin_names = @source_db.get_first_value(<<~SQL)&.then(&JSON.method(:parse))
      SELECT value
        FROM config
       WHERE name = 'enable_required_plugins'
    SQL

    return if required_plugin_names.blank?

    plugins_by_name = Discourse.plugins_by_name

    required_plugin_names.each do |plugin_name|
      if (plugin = plugins_by_name[plugin_name])
        if !plugin.enabled? && plugin.configurable?
          SiteSetting.set(plugin.enabled_site_setting, true)
        end
        puts "  #{plugin_name} plugin enabled"
      else
        puts "  ERROR: The #{plugin_name} plugin is required, but not installed."
        exit 1
      end
    end
  end

  def import_site_settings
    puts "", "Importing site settings..."

    rows = query(<<~SQL)
      SELECT name, value, action
      FROM site_settings
      ORDER BY ROWID
    SQL

    all_settings = SiteSetting.all_settings

    rows.each do |row|
      name = row["name"].to_sym
      setting = all_settings.find { |s| s[:setting] == name }
      next unless setting

      case row["action"]
      when "update"
        SiteSetting.set_and_log(name, row["value"])
      when "append"
        raise "Cannot append to #{name} setting" if setting[:type] != "list"
        items = (SiteSetting.get(name) || "").split("|")
        items << row["value"] if items.exclude?(row["value"])
        SiteSetting.set_and_log(name, items.join("|"))
      end
    end

    rows.close
  end

  def import_categories
    puts "", "Importing categories..."

    categories = query(<<~SQL)
        WITH
          RECURSIVE
          tree AS (
                    SELECT c.id, c.parent_category_id, c.name, c.description, c.color, c.text_color, c.read_restricted,
                           c.slug, c.existing_id, c.position, c.logo_upload_id, 0 AS level
                      FROM categories c
                     WHERE c.parent_category_id IS NULL
                     UNION ALL
                    SELECT c.id, c.parent_category_id, c.name, c.description, c.color, c.text_color, c.read_restricted,
                           c.slug, c.existing_id, c.position, c.logo_upload_id, tree.level + 1 AS level
                      FROM categories c,
                           tree
                     WHERE c.parent_category_id = tree.id
                  )
      SELECT id, parent_category_id, name, description, color, text_color, read_restricted, slug, existing_id, logo_upload_id,
             COALESCE(position,
                      ROW_NUMBER() OVER (PARTITION BY parent_category_id ORDER BY parent_category_id NULLS FIRST, name)) AS position
        FROM tree
       ORDER BY level, position, id
    SQL

    create_categories(categories) do |row|
      next if category_id_from_imported_id(row["id"]).present?

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

  def import_category_about_topics
    puts "", %|Creating "About..." topics for categories...|
    start_time = Time.now
    Category.ensure_consistency!
    Site.clear_cache

    categories = query(<<~SQL)
      SELECT id, about_topic_title
        FROM categories
       WHERE about_topic_title IS NOT NULL
       ORDER BY id
    SQL

    categories.each do |row|
      if (about_topic_title = row["about_topic_title"]).present?
        if (category_id = category_id_from_imported_id(row["id"]))
          topic = Category.find(category_id).topic
          topic.title = about_topic_title
          topic.save!(validate: false)
        end
      end
    end

    categories.close

    puts "  Creating took #{(Time.now - start_time).to_i} seconds."
  end

  def update_user_signatures
    puts "", "Cooking user signatures..."

    users = User.includes(:user_custom_fields).where(user_custom_fields: { name: "signature_raw" })

    users.each do |user|
      if SiteSetting.signatures_advanced_mode && user.custom_fields["signature_raw"]
        cooked_sig =
          PrettyText.cook(
            user.custom_fields["signature_raw"],
            omit_nofollow: user.has_trust_level?(TrustLevel[3]) && !SiteSetting.tl3_links_no_follow,
          )
        # avoid infinite recursion
        if cooked_sig != user.custom_fields["signature_cooked"]
          user.custom_fields["signature_cooked"] = cooked_sig
          user.save
        end
      end
    end
  end

  def import_user_custom_fields
    puts "", "Importing user custom fields..."

    user_custom_fields = query(<<~SQL)
      SELECT *
      FROM user_custom_fields
      ORDER BY user_id, name
    SQL

    field_names =
      query("SELECT DISTINCT name FROM user_custom_fields") { _1.map { |row| row["name"] } }
    existing_user_custom_fields =
      UserCustomField.where(name: field_names).pluck(:user_id, :name).to_set

    create_user_custom_fields(user_custom_fields) do |row|
      user_id = user_id_from_imported_id(row["user_id"])
      next if user_id.nil?

      next if existing_user_custom_fields.include?([user_id, row["name"]])

      {
        user_id: user_id,
        name: row["name"],
        value: raw_with_placeholders_interpolated(row["value"], row),
      }
    end

    user_custom_fields.close
  end

  def import_category_custom_fields
    puts "", "Importing category custom fields..."

    category_custom_fields = query(<<~SQL)
      SELECT *
      FROM category_custom_fields
      ORDER BY category_id, name
    SQL

    field_names =
      query("SELECT DISTINCT name FROM category_custom_fields") { _1.map { |row| row["name"] } }
    existing_category_custom_fields =
      CategoryCustomField.where(name: field_names).pluck(:category_id, :name).to_set

    create_category_custom_fields(category_custom_fields) do |row|
      category_id = category_id_from_imported_id(row["category_id"])
      next if category_id.nil?

      next if existing_category_custom_fields.include?([category_id, row["name"]])

      { category_id: category_id, name: row["name"], value: row["value"] }
    end

    category_custom_fields.close
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

  def import_category_users
    puts "", "Importing category users..."

    category_users = query(<<~SQL)
      SELECT *
        FROM category_users
       ORDER BY category_id, user_id
    SQL

    existing_category_user_ids = CategoryUser.pluck(:category_id, :user_id).to_set

    create_category_users(category_users) do |row|
      category_id = category_id_from_imported_id(row["category_id"])
      user_id = user_id_from_imported_id(row["user_id"])
      next if existing_category_user_ids.include?([category_id, user_id])

      {
        category_id: category_id,
        user_id: user_id,
        notification_level: row["notification_level"],
        last_seen_at: to_datetime(row["last_seen_at"]),
      }
    end

    category_users.close
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
      group_id =
        (
          if row["existing_id"].nil?
            group_id_from_imported_id(row["group_id"])
          else
            row["existing_id"].to_i
          end
        )
      user_id = user_id_from_imported_id(row["user_id"])
      next if user_id.nil?
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
        row["username"] = "anon_#{anon_username_suffix}"
        row["email"] = "#{row["username"]}#{UserAnonymizer::EMAIL_SUFFIX}"
        row["name"] = nil
        row["registration_ip_address"] = nil
        row["date_of_birth"] = nil
      end

      {
        imported_id: row["id"],
        username: row["username"],
        original_username: row["original_username"],
        name: row["name"],
        email: row["email"],
        external_id: sso_record&.fetch("external_id", nil),
        created_at: to_datetime(row["created_at"]),
        last_seen_at: to_datetime(row["last_seen_at"]),
        admin: row["admin"],
        moderator: row["moderator"],
        suspended_at: suspended_at,
        suspended_till: suspended_till,
        registration_ip_address: row["registration_ip_address"],
        date_of_birth: to_date(row["date_of_birth"]),
        trust_level: row["trust_level"],
        flair_group_id: row["flair_group_id"],
      }
    end

    users.close
  end

  def import_user_emails
    puts "", "Importing user emails..."

    existing_user_ids = UserEmail.pluck(:user_id).to_set

    users = query(<<~SQL)
      SELECT id, email, created_at, anonymized
      FROM users
      ORDER BY id
    SQL

    create_user_emails(users) do |row|
      user_id = user_id_from_imported_id(row["id"])
      next if user_id && existing_user_ids.include?(user_id)

      if row["anonymized"] == 1
        username = username_from_id(user_id)
        row["email"] = "#{username}#{UserAnonymizer::EMAIL_SUFFIX}"
      end

      { user_id: user_id, email: row["email"], created_at: to_datetime(row["created_at"]) }
    end

    users.close
  end

  def import_user_profiles
    puts "", "Importing user profiles..."

    users = query(<<~SQL)
      SELECT id, bio, location, website, anonymized
      FROM users
      ORDER BY id
    SQL

    existing_user_ids = UserProfile.pluck(:user_id).to_set

    create_user_profiles(users) do |row|
      user_id = user_id_from_imported_id(row["id"])
      next if user_id && existing_user_ids.include?(user_id)

      if row["anonymized"] == 1
        row["bio"] = nil
        row["location"] = nil
        row["website"] = nil
      end

      { user_id: user_id, bio_raw: row["bio"], location: row["location"], website: row["website"] }
    end

    users.close
  end

  def import_user_options
    puts "", "Importing user options..."

    users = query(<<~SQL)
      SELECT id, timezone, email_level, email_messages_level, email_digests
        FROM users
       WHERE timezone IS NOT NULL
          OR email_level IS NOT NULL
          OR email_messages_level IS NOT NULL
          OR email_digests IS NOT NULL
       ORDER BY id
    SQL

    existing_user_ids = UserOption.pluck(:user_id).to_set

    create_user_options(users) do |row|
      user_id = user_id_from_imported_id(row["id"])
      next if user_id && existing_user_ids.include?(user_id)

      {
        user_id: user_id,
        timezone: row["timezone"],
        email_level: row["email_level"],
        email_messages_level: row["email_messages_level"],
        email_digests: row["email_digests"],
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

      # TODO: Use `id` and store it in mapping table, but for now just ignore it.
      row.delete("id")
      options = row.delete("options")
      field = UserField.create!(row)

      if options.present?
        JSON.parse(options).each { |option| field.user_field_options.create!(value: option) }
      end
    end

    user_fields.close
  end

  def import_user_field_values
    puts "", "Importing user field values..."

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

    # TODO make restriction to non-anonymized users configurable
    values = query(<<~SQL)
      SELECT v.*
        FROM user_field_values v
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

  def import_user_associated_accounts
    puts "", "Importing user associated accounts..."

    accounts = query(<<~SQL)
      SELECT a.*, COALESCE(u.last_seen_at, u.created_at) AS last_used_at, u.email, u.username
        FROM user_associated_accounts a
             JOIN users u ON u.id = a.user_id
       ORDER BY a.user_id, a.provider_name
    SQL

    existing_user_ids = UserAssociatedAccount.pluck(:user_id).to_set
    existing_provider_uids = UserAssociatedAccount.pluck(:provider_uid, :provider_name).to_set

    create_user_associated_accounts(accounts) do |row|
      user_id = user_id_from_imported_id(row["user_id"])

      next if user_id && existing_user_ids.include?(user_id)
      next if existing_provider_uids.include?([row["provider_uid"], row["provider_name"]])

      {
        user_id: user_id,
        provider_name: row["provider_name"],
        provider_uid: row["provider_uid"],
        last_used: to_datetime(row["last_used_at"]),
        info: row["info"].presence || { nickname: row["username"], email: row["email"] }.to_json,
      }
    end

    accounts.close
  end

  def import_topics
    puts "", "Importing topics..."

    topics = query(<<~SQL)
      SELECT *
      FROM topics
      ORDER BY id
    SQL

    create_topics(topics) do |row|
      category_id = category_id_from_imported_id(row["category_id"]) if row["category_id"].present?

      next if topic_id_from_imported_id(row["id"]).present?
      next if row["private_message"].blank? && category_id.nil?

      {
        archetype: row["private_message"] ? Archetype.private_message : Archetype.default,
        imported_id: row["id"],
        title: row["title"],
        user_id: user_id_from_imported_id(row["user_id"]),
        created_at: to_datetime(row["created_at"]),
        category_id: category_id,
        closed: to_boolean(row["closed"]),
        views: row["views"],
        subtype: row["subtype"],
        pinned_at: to_datetime(row["pinned_at"]),
        pinned_until: to_datetime(row["pinned_until"]),
        pinned_globally: to_boolean(row["pinned_globally"]),
      }
    end

    topics.close
  end

  def import_topic_allowed_users
    puts "", "Importing topic_allowed_users..."

    topics = query(<<~SQL)
      SELECT
        t.id,
        user_ids.value AS user_id
      FROM topics t, JSON_EACH(t.private_message, '$.user_ids') AS user_ids
      WHERE t.private_message IS NOT NULL
      ORDER BY t.id
    SQL

    added = 0
    existing_topic_allowed_users = TopicAllowedUser.pluck(:topic_id, :user_id).to_set

    create_topic_allowed_users(topics) do |row|
      topic_id = topic_id_from_imported_id(row["id"])
      user_id = user_id_from_imported_id(row["user_id"])

      next unless topic_id && user_id
      next unless existing_topic_allowed_users.add?([topic_id, user_id])

      added += 1

      { topic_id: topic_id, user_id: user_id }
    end

    topics.close

    puts "  Added #{added} topic_allowed_users records."
  end

  def import_topic_allowed_groups
    puts "", "Importing topic_allowed_groups..."

    topics = query(<<~SQL)
      SELECT
        t.id,
        group_ids.value AS group_id
      FROM topics t, JSON_EACH(t.private_message, '$.group_ids') AS group_ids
      WHERE t.private_message IS NOT NULL
      ORDER BY t.id
    SQL

    added = 0
    existing_topic_allowed_groups = TopicAllowedGroup.pluck(:topic_id, :group_id).to_set

    create_topic_allowed_groups(topics) do |row|
      topic_id = topic_id_from_imported_id(row["id"])
      group_id = group_id_from_imported_id(row["group_id"])

      next unless topic_id && group_id
      next unless existing_topic_allowed_groups.add?([topic_id, group_id])

      added += 1

      { topic_id: topic_id, group_id: group_id }
    end

    # TODO: Add support for special group names

    topics.close

    puts "  Added #{added} topic_allowed_groups records."
  end

  def import_posts
    puts "", "Importing posts..."

    posts = query(<<~SQL)
      SELECT *
      FROM posts
      ORDER BY topic_id, post_number, id
    SQL

    create_posts(posts) do |row|
      next if row["raw"].blank?
      next unless (topic_id = topic_id_from_imported_id(row["topic_id"]))
      next if post_id_from_imported_id(row["id"]).present?

      # TODO Ensure that we calculate the `like_count` if the column is empty, but the DB contains likes.
      # Otherwise #import_user_stats will not be able to calculate the correct `likes_received` value.

      {
        imported_id: row["id"],
        topic_id: topic_id,
        user_id: user_id_from_imported_id(row["user_id"]),
        created_at: to_datetime(row["created_at"]),
        raw: raw_with_placeholders_interpolated(row["raw"], row),
        like_count: row["like_count"],
        reply_to_post_number:
          row["reply_to_post_id"] ? post_number_from_imported_id(row["reply_to_post_id"]) : nil,
      }
    end

    posts.close
  end

  def group_id_name_map
    @group_id_name_map ||= Group.pluck(:id, :name).to_h
  end

  def raw_with_placeholders_interpolated(raw, row)
    raw = raw.dup
    placeholders = row["placeholders"]&.then { |json| JSON.parse(json) }

    if (polls = placeholders&.fetch("polls", nil))
      poll_mapping = polls.map { |poll| [poll["poll_id"], poll["placeholder"]] }.to_h

      poll_details = query(<<~SQL, { post_id: row["id"] })
        SELECT p.*, ROW_NUMBER() OVER (PARTITION BY p.post_id, p.name ORDER BY p.id) AS seq,
               JSON_GROUP_ARRAY(DISTINCT TRIM(po.text)) AS options
          FROM polls p
               JOIN poll_options po ON p.id = po.poll_id
         WHERE p.post_id = :post_id
         ORDER BY p.id, po.position, po.id
      SQL

      poll_details.each do |poll|
        if (placeholder = poll_mapping[poll["id"]])
          raw.gsub!(placeholder, poll_bbcode(poll))
        end
      end

      poll_details.close
    end

    if (mentions = placeholders&.fetch("mentions", nil))
      mentions.each do |mention|
        name = resolve_mentioned_name(mention)

        if name
          raw.gsub!(mention["placeholder"], " @#{name} ")
        else
          unless ENV["NO_MENTION_WARNINGS"]
            puts "#{mention["type"]} not found -- #{mention["placeholder"]}"
          end
          raw.gsub!(mention["placeholder"], " `@#{mention["type"]}_not_found` ")
        end
      end
    end

    if (event = placeholders&.fetch("event", nil))
      event_details = @source_db.get_first_row(<<~SQL, { event_id: event["event_id"] })
        SELECT *
          FROM events
         WHERE id = :event_id
      SQL

      raw.gsub!(event["placeholder"], event_bbcode(event_details)) if event_details
    end

    if (quotes = placeholders&.fetch("quotes", nil))
      quotes.each do |quote|
        user_id =
          if quote["user_id"]
            user_id_from_imported_id(quote["user_id"])
          elsif quote["username"]
            user_id_from_original_username(quote["username"])
          end

        username = quote["username"]
        name = nil

        if user_id
          username = username_from_id(user_id)
          name = user_full_name_from_id(user_id)
        end

        if quote["post_id"]
          topic_id = topic_id_from_imported_post_id(quote["post_id"])
          post_number = post_number_from_imported_id(quote["post_id"])
        end

        bbcode =
          if username.blank? && name.blank?
            "[quote]"
          else
            bbcode_parts = []
            bbcode_parts << name.presence || username
            bbcode_parts << "post:#{post_number}" if post_number.present?
            bbcode_parts << "topic:#{topic_id}" if topic_id.present?
            bbcode_parts << "username:#{username}" if username.present? && name.present?

            %Q|[quote="#{bbcode_parts.join(", ")}"]|
          end

        raw.gsub!(quote["placeholder"], bbcode)
      end
    end

    if (links = placeholders&.fetch("links", nil))
      links.each do |link|
        text = link["text"]
        original_url = link["url"]

        markdown =
          if link["topic_id"]
            topic_id = topic_id_from_imported_id(link["topic_id"])
            url = topic_id ? "#{Discourse.base_url}/t/#{topic_id}" : original_url
            text ? "[#{text}](#{url})" : url
          elsif link["post_id"]
            topic_id = topic_id_from_imported_post_id(link["post_id"])
            post_number = post_number_from_imported_id(link["post_id"])
            url =
              (
                if topic_id && post_number
                  "#{Discourse.base_url}/t/#{topic_id}/#{post_number}"
                else
                  original_url
                end
              )
            text ? "[#{text}](#{url})" : url
          else
            text ? "[#{text}](#{original_url})" : original_url
          end

        # ensure that the placeholder is surrounded by whitespace unless it's at the beginning or end of the string
        placeholder = link["placeholder"]
        escaped_placeholder = Regexp.escape(placeholder)
        raw.gsub!(/(?<!\s)#{escaped_placeholder}/, " #{placeholder}")
        raw.gsub!(/#{escaped_placeholder}(?!\s)/, "#{placeholder} ")

        raw.gsub!(placeholder, markdown)
      end
    end

    if row["upload_ids"].present? && @uploads_db
      upload_ids = JSON.parse(row["upload_ids"])
      upload_ids_placeholders = (["?"] * upload_ids.size).join(",")

      query(
        "SELECT id, markdown FROM uploads WHERE id IN (#{upload_ids_placeholders})",
        upload_ids,
        db: @uploads_db,
      ).tap do |result_set|
        result_set.each { |upload| raw.gsub!("[upload|#{upload["id"]}]", upload["markdown"] || "") }
        result_set.close
      end
    end

    raw
  end

  def resolve_mentioned_name(mention)
    # NOTE: original_id lookup order is important until post and chat mentions are unified
    original_id = mention["target_id"] || mention["id"]
    name = mention["name"]

    case mention["type"]
    when "user", "Chat::UserMention"
      resolved_user_name(original_id, name)
    when "group", "Chat::GroupMention"
      resolved_group_name(original_id, name)
    when "Chat::HereMention"
      "here"
    when "Chat::AllMention"
      "all"
    end
  end

  def resolved_user_name(original_id, name)
    user_id =
      if original_id
        user_id_from_imported_id(original_id)
      elsif name
        user_id_from_original_username(name)
      end

    user_id ? username_from_id(user_id) : name
  end

  def resolved_group_name(original_id, name)
    group_id = group_id_from_imported_id(original_id) if original_id

    group_id ? group_id_name_map[group_id] : name
  end

  def process_raw(original_raw)
    original_raw
  end

  def poll_name(row)
    name = +(row["name"] || "poll")
    name << "-#{row["seq"]}" if row["seq"] > 1
    name
  end

  def poll_bbcode(row)
    return unless defined?(::Poll)

    name = poll_name(row)
    type = ::Poll.types.key(row["type"])
    regular_type = type == ::Poll.types[:regular]
    number_type = type == ::Poll.types[:number]
    result_visibility = ::Poll.results.key(row["results"])
    min = row["min"]
    max = row["max"]
    step = row["step"]
    visibility = row["visibility"]
    chart_type = ::Poll.chart_types.key(row["chart_type"])
    groups = row["groups"]
    auto_close = to_datetime(row["close_at"])
    title = row["title"]
    options = JSON.parse(row["options"])

    text = +"[poll"
    text << " name=#{name}" if name != "poll"
    text << " type=#{type}"
    text << " results=#{result_visibility}"
    text << " min=#{min}" if min && !regular_type
    text << " max=#{max}" if max && !regular_type
    text << " step=#{step}" if step && !number_type
    text << " public=true" if visibility == Poll.visibilities[:everyone]
    text << " chartType=#{chart_type}" if chart_type.present? && !regular_type
    text << " groups=#{groups.join(",")}" if groups.present?
    text << " close=#{auto_close.utc.iso8601}" if auto_close
    text << "]\n"
    text << "# #{title}\n" if title.present?
    text << options.map { |o| "* #{o}" }.join("\n") if options.present? && !number_type
    text << "\n[/poll]\n"
    text
  end

  def event_bbcode(event)
    return unless defined?(::DiscoursePostEvent)

    starts_at = to_datetime(event["starts_at"])
    ends_at = to_datetime(event["ends_at"])
    status = ::DiscoursePostEvent::Event.statuses[event["status"]].to_s
    name =
      if (name = event["name"].presence)
        name.ljust(::DiscoursePostEvent::Event::MIN_NAME_LENGTH, ".").truncate(
          ::DiscoursePostEvent::Event::MAX_NAME_LENGTH,
        )
      end
    url = event["url"]
    custom_fields = event["custom_fields"] ? JSON.parse(event["custom_fields"]) : nil

    text = +"[event"
    text << %{ start="#{starts_at.utc.strftime("%Y-%m-%d %H:%M")}"} if starts_at
    text << %{ end="#{ends_at.utc.strftime("%Y-%m-%d %H:%M")}"} if ends_at
    text << %{ timezone="UTC"}
    text << %{ status="#{status}"} if status
    text << %{ name="#{name}"} if name
    text << %{ url="#{url}"} if url
    custom_fields.each { |key, value| text << %{ #{key}="#{value}"} } if custom_fields
    text << "]\n"
    text << "[/event]\n"
    text
  end

  def import_post_custom_fields
    puts "", "Importing post custom fields..."

    post_custom_fields = query(<<~SQL)
      SELECT *
      FROM post_custom_fields
      ORDER BY post_id, name
    SQL

    field_names =
      query("SELECT DISTINCT name FROM post_custom_fields") { _1.map { |row| row["name"] } }
    existing_post_custom_fields =
      PostCustomField.where(name: field_names).pluck(:post_id, :name).to_set

    create_post_custom_fields(post_custom_fields) do |row|
      post_id = post_id_from_imported_id(row["post_id"])
      next if post_id.nil?

      next if existing_post_custom_fields.include?([post_id, row["name"]])

      { post_id: post_id, name: row["name"], value: row["value"] }
    end

    post_custom_fields.close
  end

  def import_topic_custom_fields
    puts "", "Importing topic custom fields..."

    topic_custom_fields = query(<<~SQL)
      SELECT *
      FROM topic_custom_fields
      ORDER BY topic_id, name
    SQL

    field_names =
      query("SELECT DISTINCT name FROM topic_custom_fields") { _1.map { |row| row["name"] } }
    existing_topic_custom_fields =
      TopicCustomField.where(name: field_names).pluck(:topic_id, :name).to_set

    create_topic_custom_fields(topic_custom_fields) do |row|
      topic_id = topic_id_from_imported_id(row["topic_id"])
      next if topic_id.nil?

      next if existing_topic_custom_fields.include?([topic_id, row["name"]])

      { topic_id: topic_id, name: row["name"], value: row["value"] }
    end

    topic_custom_fields.close
  end

  def import_polls
    unless defined?(::Poll)
      puts "", "Skipping polls, because the poll plugin is not installed."
      return
    end

    puts "", "Importing polls..."

    polls = query(<<~SQL)
      SELECT *, ROW_NUMBER() OVER (PARTITION BY post_id, name ORDER BY id) AS seq
        FROM polls
       ORDER BY id
    SQL

    create_polls(polls) do |row|
      next if poll_id_from_original_id(row["id"]).present?

      post_id = post_id_from_imported_id(row["post_id"])
      next unless post_id

      {
        original_id: row["id"],
        post_id: post_id,
        name: poll_name(row),
        closed_at: to_datetime(row["closed_at"]),
        type: row["type"],
        status: row["status"],
        results: row["results"],
        visibility: row["visibility"],
        min: row["min"],
        max: row["max"],
        step: row["step"],
        anonymous_voters: row["anonymous_voters"],
        created_at: to_datetime(row["created_at"]),
        chart_type: row["chart_type"],
        groups: row["groups"],
        title: row["title"],
      }
    end

    polls.close

    puts "", "Importing polls into post custom fields..."

    polls = query(<<~SQL)
      SELECT post_id, MIN(created_at) AS created_at
        FROM polls
       GROUP BY post_id
       ORDER BY post_id
    SQL

    field_name = DiscoursePoll::HAS_POLLS
    value = "true"
    existing_fields = PostCustomField.where(name: field_name).pluck(:post_id).to_set

    create_post_custom_fields(polls) do |row|
      next unless (post_id = post_id_from_imported_id(row["post_id"]))
      next if existing_fields.include?(post_id)

      {
        post_id: post_id,
        name: field_name,
        value: value,
        created_at: to_datetime(row["created_at"]),
      }
    end

    polls.close
  end

  def import_poll_options
    unless defined?(::Poll)
      puts "", "Skipping polls, because the poll plugin is not installed."
      return
    end

    puts "", "Importing poll options..."

    poll_options = query(<<~SQL)
      SELECT poll_id, TRIM(text) AS text, MIN(created_at) AS created_at, GROUP_CONCAT(id) AS option_ids
        FROM poll_options
       GROUP BY 1, 2
       ORDER BY poll_id, position, id
    SQL

    create_poll_options(poll_options) do |row|
      poll_id = poll_id_from_original_id(row["poll_id"])
      next unless poll_id

      option_ids = row["option_ids"].split(",")
      option_ids.each { |option_id| next if poll_option_id_from_original_id(option_id).present? }

      {
        original_ids: option_ids,
        poll_id: poll_id,
        html: row["text"],
        created_at: to_datetime(row["created_at"]),
      }
    end

    poll_options.close
  end

  def import_poll_votes
    unless defined?(::Poll)
      puts "", "Skipping polls, because the poll plugin is not installed."
      return
    end

    puts "", "Importing poll votes..."

    poll_votes = query(<<~SQL)
      SELECT po.poll_id, pv.poll_option_id, pv.user_id, pv.created_at
        FROM poll_votes pv
             JOIN poll_options po ON pv.poll_option_id = po.id
       ORDER BY pv.poll_option_id, pv.user_id
    SQL

    existing_poll_votes = PollVote.pluck(:poll_option_id, :user_id).to_set

    create_poll_votes(poll_votes) do |row|
      poll_id = poll_id_from_original_id(row["poll_id"])
      poll_option_id = poll_option_id_from_original_id(row["poll_option_id"])
      user_id = user_id_from_imported_id(row["user_id"])
      next unless poll_id && poll_option_id && user_id

      next unless existing_poll_votes.add?([poll_option_id, user_id])

      {
        poll_id: poll_id,
        poll_option_id: poll_option_id,
        user_id: user_id,
        created_at: row["created_at"],
      }
    end

    poll_votes.close
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

    puts "", "Updating like counts of posts..."
    start_time = Time.now

    DB.exec(<<~SQL)
        WITH
          likes AS (
                     SELECT post_id, COUNT(*) AS like_count FROM post_actions WHERE post_action_type_id = 2 GROUP BY post_id
                   )
      UPDATE posts
         SET like_count = likes.like_count
        FROM likes
       WHERE posts.id = likes.post_id
         AND posts.like_count <> likes.like_count
    SQL

    puts "", "Updating like counts of topics..."

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

  def import_topic_users
    puts "", "Importing topic users..."

    topic_users = query(<<~SQL)
      SELECT *
        FROM topic_users
       ORDER BY user_id, topic_id
    SQL

    existing_topics = TopicUser.pluck(:topic_id).to_set

    create_topic_users(topic_users) do |row|
      user_id = user_id_from_imported_id(row["user_id"])
      topic_id = topic_id_from_imported_id(row["topic_id"])
      next unless user_id && topic_id
      next if existing_topics.include?(topic_id)

      {
        user_id: user_id,
        topic_id: topic_id,
        last_read_post_number: row["last_read_post_number"],
        last_visited_at: to_datetime(row["last_visited_at"]),
        first_visited_at: to_datetime(row["first_visited_at"]),
        notification_level: row["notification_level"],
        notifications_changed_at: to_datetime(row["notifications_changed_at"]),
        notifications_reason_id:
          row["notifications_reason_id"] || TopicUser.notification_reasons[:user_changed],
        total_msecs_viewed: row["total_msecs_viewed"] || 0,
      }
    end

    topic_users.close
  end

  def update_topic_users
    puts "", "Updating topic users..."

    start_time = Time.now

    params = {
      post_action_type_id: PostActionType.types[:like],
      msecs_viewed_per_post: 10_000,
      notification_level_topic_created: NotificationLevels.topic_levels[:watching],
      notification_level_posted: NotificationLevels.topic_levels[:tracking],
      reason_topic_created: TopicUser.notification_reasons[:created_topic],
      reason_posted: TopicUser.notification_reasons[:created_post],
    }

    DB.exec(<<~SQL, params)
      INSERT INTO topic_users (user_id, topic_id, posted, last_read_post_number, first_visited_at, last_visited_at,
                               notification_level, notifications_changed_at, notifications_reason_id, total_msecs_viewed,
                               last_posted_at)
      SELECT p.user_id, p.topic_id, TRUE AS posted, MAX(p.post_number) AS last_read_post_number,
             MIN(p.created_at) AS first_visited_at, MAX(p.created_at) AS last_visited_at,
             CASE WHEN MIN(p.post_number) = 1 THEN :notification_level_topic_created
                  ELSE :notification_level_posted END AS notification_level, MIN(p.created_at) AS notifications_changed_at,
             CASE WHEN MIN(p.post_number) = 1 THEN :reason_topic_created ELSE :reason_posted END AS notifications_reason_id,
             MAX(p.post_number) * :msecs_viewed_per_post AS total_msecs_viewed, MAX(p.created_at) AS last_posted_at
        FROM posts p
             JOIN topics t ON p.topic_id = t.id
       WHERE p.user_id > 0
         AND p.deleted_at IS NULL
         AND NOT p.hidden
         AND t.deleted_at IS NULL
         AND t.visible
       GROUP BY p.user_id, p.topic_id
          ON CONFLICT (user_id, topic_id) DO UPDATE SET posted = excluded.posted,
                                                        last_read_post_number = GREATEST(topic_users.last_read_post_number, excluded.last_read_post_number),
                                                        first_visited_at = LEAST(topic_users.first_visited_at, excluded.first_visited_at),
                                                        last_visited_at = GREATEST(topic_users.last_visited_at, excluded.last_visited_at),
                                                        notification_level = GREATEST(topic_users.notification_level, excluded.notification_level),
                                                        notifications_changed_at = CASE WHEN COALESCE(excluded.notification_level, 0) > COALESCE(topic_users.notification_level, 0)
                                                                                          THEN COALESCE(excluded.notifications_changed_at, topic_users.notifications_changed_at)
                                                                                        ELSE topic_users.notifications_changed_at END,
                                                        notifications_reason_id = CASE WHEN COALESCE(excluded.notification_level, 0) > COALESCE(topic_users.notification_level, 0)
                                                                                         THEN COALESCE(excluded.notifications_reason_id, topic_users.notifications_reason_id)
                                                                                       ELSE topic_users.notifications_reason_id END,
                                                        total_msecs_viewed = CASE WHEN topic_users.total_msecs_viewed = 0
                                                                                    THEN excluded.total_msecs_viewed
                                                                                  ELSE topic_users.total_msecs_viewed END,
                                                        last_posted_at = GREATEST(topic_users.last_posted_at, excluded.last_posted_at)
    SQL

    DB.exec(<<~SQL, params)
      INSERT INTO topic_users (user_id, topic_id, last_read_post_number, first_visited_at, last_visited_at, total_msecs_viewed, liked)
      SELECT pa.user_id, p.topic_id, MAX(p.post_number) AS last_read_post_number, MIN(pa.created_at) AS first_visited_at,
             MAX(pa.created_at) AS last_visited_at, MAX(p.post_number) * :msecs_viewed_per_post AS total_msecs_viewed,
             TRUE AS liked
        FROM post_actions pa
             JOIN posts p ON pa.post_id = p.id
             JOIN topics t ON p.topic_id = t.id
       WHERE pa.post_action_type_id = :post_action_type_id
         AND pa.user_id > 0
         AND pa.deleted_at IS NULL
         AND p.deleted_at IS NULL
         AND NOT p.hidden
         AND t.deleted_at IS NULL
         AND t.visible
       GROUP BY pa.user_id, p.topic_id
          ON CONFLICT (user_id, topic_id) DO UPDATE SET last_read_post_number = GREATEST(topic_users.last_read_post_number, excluded.last_read_post_number),
                                                        first_visited_at = LEAST(topic_users.first_visited_at, excluded.first_visited_at),
                                                        last_visited_at = GREATEST(topic_users.last_visited_at, excluded.last_visited_at),
                                                        total_msecs_viewed = CASE WHEN topic_users.total_msecs_viewed = 0
                                                                                    THEN excluded.total_msecs_viewed
                                                                                  ELSE topic_users.total_msecs_viewed END,
                                                        liked = excluded.liked
    SQL

    puts "  Updated topic users in #{(Time.now - start_time).to_i} seconds."
  end

  def import_user_stats
    puts "", "Importing user stats..."

    start_time = Time.now

    # TODO Merge with #update_user_stats from import.rake and check if there are privacy concerns
    # E.g. maybe we need to exclude PMs from the calculation?

    DB.exec(<<~SQL)
        WITH
          visible_posts AS (
                             SELECT p.id, p.post_number, p.user_id, p.created_at, p.like_count, p.topic_id
                               FROM posts p
                                    JOIN topics t ON p.topic_id = t.id
                              WHERE t.archetype = 'regular'
                                AND t.deleted_at IS NULL
                                AND t.visible
                                AND p.deleted_at IS NULL
                                AND p.post_type = 1 /* regular_post_type */
                                AND NOT p.hidden
                           ),
          topic_stats AS (
                             SELECT t.user_id, COUNT(t.id) AS topic_count
                               FROM topics t
                              WHERE t.archetype = 'regular'
                                AND t.deleted_at IS NULL
                                AND t.visible
                              GROUP BY t.user_id
                           ),
          post_stats AS (
                             SELECT p.user_id, MIN(p.created_at) AS first_post_created_at, SUM(p.like_count) AS likes_received
                               FROM visible_posts p
                              GROUP BY p.user_id
                           ),
          reply_stats AS (
                             SELECT p.user_id, COUNT(p.id) AS reply_count
                               FROM visible_posts p
                              WHERE p.post_number > 1
                              GROUP BY p.user_id
                           ),
          like_stats AS (
                             SELECT pa.user_id, COUNT(*) AS likes_given
                               FROM post_actions pa
                                    JOIN visible_posts p ON pa.post_id = p.id
                              WHERE pa.post_action_type_id = 2 /* like */
                                AND pa.deleted_at IS NULL
                              GROUP BY pa.user_id
                           ),
          badge_stats AS (
                             SELECT ub.user_id, COUNT(DISTINCT ub.badge_id) AS distinct_badge_count
                               FROM user_badges ub
                                    JOIN badges b ON ub.badge_id = b.id AND b.enabled
                              GROUP BY ub.user_id
                           ),
          post_action_stats AS ( -- posts created by user and likes given by user
                             SELECT p.user_id, p.id AS post_id, p.created_at::DATE, p.topic_id, p.post_number
                               FROM visible_posts p
                              UNION
                             SELECT pa.user_id, pa.post_id, pa.created_at::DATE, p.topic_id, p.post_number
                               FROM post_actions pa
                                    JOIN visible_posts p ON pa.post_id = p.id
                              WHERE pa.post_action_type_id = 2
                           ),
          topic_reading_stats AS (
                             SELECT user_id, COUNT(DISTINCT topic_id) AS topics_entered,
                                    COUNT(DISTINCT created_at) AS days_visited
                               FROM post_action_stats
                              GROUP BY user_id
                           ),
          posts_reading_stats AS (
                             SELECT user_id, SUM(max_post_number) AS posts_read_count
                               FROM (
                                      SELECT user_id, MAX(post_number) AS max_post_number
                                        FROM post_action_stats
                                       GROUP BY user_id, topic_id
                                    ) x
                              GROUP BY user_id
                           )
      INSERT
        INTO user_stats (user_id, new_since, post_count, topic_count, first_post_created_at, likes_received,
                         likes_given, distinct_badge_count, days_visited, topics_entered, posts_read_count, time_read)
      SELECT u.id AS user_id, u.created_at AS new_since, COALESCE(rs.reply_count, 0) AS reply_count,
             COALESCE(ts.topic_count, 0) AS topic_count, ps.first_post_created_at,
             COALESCE(ps.likes_received, 0) AS likes_received, COALESCE(ls.likes_given, 0) AS likes_given,
             COALESCE(bs.distinct_badge_count, 0) AS distinct_badge_count, COALESCE(trs.days_visited, 1) AS days_visited,
             COALESCE(trs.topics_entered, 0) AS topics_entered, COALESCE(prs.posts_read_count, 0) AS posts_read_count,
             COALESCE(prs.posts_read_count, 0) * 30 AS time_read -- assume 30 seconds / post
        FROM users u
             LEFT JOIN topic_stats ts ON u.id = ts.user_id
             LEFT JOIN post_stats ps ON u.id = ps.user_id
             LEFT JOIN reply_stats rs ON u.id = rs.user_id
             LEFT JOIN like_stats ls ON u.id = ls.user_id
             LEFT JOIN badge_stats bs ON u.id = bs.user_id
             LEFT JOIN topic_reading_stats trs ON u.id = trs.user_id
             LEFT JOIN posts_reading_stats prs ON u.id = prs.user_id
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
      acting_user_id = user_id_from_imported_id(row["acting_user_id"])
      next if user_id && existing_user_ids.include?(user_id)

      {
        action: action_id,
        acting_user_id: acting_user_id || Discourse::SYSTEM_USER_ID,
        target_user_id: user_id,
        details: row["reason"],
      }
    end

    user_histories.close
  end

  def import_user_notes
    puts "", "Importing user notes..."

    unless defined?(::DiscourseUserNotes)
      puts "  Skipping import of user notes because the plugin is not installed."
      return
    end

    user_notes = query(<<~SQL)
      SELECT user_id,
             JSON_GROUP_ARRAY(JSON_OBJECT('raw', raw, 'created_by', created_by_user_id, 'created_at',
                                          created_at)) AS note_json_text
        FROM user_notes
       GROUP BY user_id
       ORDER BY user_id, id
    SQL

    existing_user_ids =
      PluginStoreRow
        .where(plugin_name: "user_notes")
        .pluck(:key)
        .map { |key| key.delete_prefix("notes:").to_i }
        .to_set

    create_plugin_store_rows(user_notes) do |row|
      user_id = user_id_from_imported_id(row["user_id"])
      next if !user_id || existing_user_ids.include?(user_id)

      notes = JSON.parse(row["note_json_text"], symbolize_names: true)
      notes.each do |note|
        note[:id] = SecureRandom.hex(16)
        note[:user_id] = user_id
        note[:created_by] = (
          if note[:created_by]
            user_id_from_imported_id(note[:created_by])
          else
            Discourse::SYSTEM_USER_ID
          end
        )
        note[:created_at] = to_datetime(note[:created_at])
      end

      {
        plugin_name: "user_notes",
        key: "notes:#{user_id}",
        type_name: "JSON",
        value: notes.to_json,
      }
    end

    user_notes.close
  end

  def import_user_note_counts
    puts "", "Importing user note counts..."

    unless defined?(::DiscourseUserNotes)
      puts "  Skipping import of user notes because the plugin is not installed."
      return
    end

    user_note_counts = query(<<~SQL)
      SELECT user_id, COUNT(*) AS count
        FROM user_notes
       GROUP BY user_id
       ORDER BY user_id
    SQL

    existing_user_ids = UserCustomField.where(name: "user_notes_count").pluck(:user_id).to_set

    create_user_custom_fields(user_note_counts) do |row|
      user_id = user_id_from_imported_id(row["user_id"])
      next if !user_id || existing_user_ids.include?(user_id)

      { user_id: user_id, name: "user_notes_count", value: row["count"].to_s }
    end

    user_note_counts.close
  end

  def import_user_followers
    puts "", "Importing user followers..."

    unless defined?(::Follow)
      puts "  Skipping import of user followers because the plugin is not installed."
      return
    end

    user_followers = query(<<~SQL)
      SELECT *
        FROM user_followers
       ORDER BY user_id, follower_id
    SQL

    existing_followers = UserFollower.pluck(:user_id, :follower_id).to_set
    notification_level = Follow::Notification.levels[:watching]

    create_user_followers(user_followers) do |row|
      user_id = user_id_from_imported_id(row["user_id"])
      follower_id = user_id_from_imported_id(row["follower_id"])

      next if !user_id || !follower_id || existing_followers.include?([user_id, follower_id])

      {
        user_id: user_id,
        follower_id: follower_id,
        level: notification_level,
        created_at: to_datetime(row["created_at"]),
      }
    end

    user_followers.close
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

  def import_optimized_images
    return if !@uploads_db

    puts "", "Importing optimized images..."

    optimized_images = query(<<~SQL, db: @uploads_db)
      SELECT oi.id AS upload_id, x.value AS optimized_image
        FROM optimized_images oi,
             JSON_EACH(oi.optimized_images) x
       WHERE optimized_images IS NOT NULL
       ORDER BY oi.rowid, x.value -> 'id'
    SQL

    DB.exec(<<~SQL)
      DELETE
        FROM optimized_images oi
       WHERE EXISTS (
                      SELECT 1
                        FROM migration_mappings mm
                       WHERE mm.type = 1
                         AND mm.discourse_id::BIGINT = oi.upload_id
                    )
    SQL

    existing_optimized_images = OptimizedImage.pluck(:upload_id, :height, :width).to_set

    create_optimized_images(optimized_images) do |row|
      upload_id = upload_id_from_original_id(row["upload_id"])
      next unless upload_id

      optimized_image = JSON.parse(row["optimized_image"], symbolize_names: true)

      unless existing_optimized_images.add?(
               [upload_id, optimized_image[:height], optimized_image[:width]],
             )
        next
      end

      optimized_image[:upload_id] = upload_id
      optimized_image
    end

    optimized_images.close
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

    puts "", "Importing upload references for badges..."
    start_time = Time.now
    DB.exec(<<~SQL)
      INSERT INTO upload_references (upload_id, target_type, target_id, created_at, updated_at)
      SELECT image_upload_id, 'Badge', id, created_at, updated_at
        FROM badges b
       WHERE image_upload_id IS NOT NULL
         AND NOT EXISTS (
                          SELECT 1
                            FROM upload_references ur
                           WHERE ur.upload_id = b.image_upload_id
                             AND ur.target_type = 'Badge'
                             AND ur.target_id = b.id
                        )
          ON CONFLICT DO NOTHING
    SQL
    puts "  Import took #{(Time.now - start_time).to_i} seconds."

    import_content_upload_references("posts")
    import_content_upload_references("chat_messages")
  end

  def import_content_upload_references(type)
    if CONTENT_UPLOAD_REFERENCE_TYPES.exclude?(type)
      puts "  Skipping upload references import for #{type} because it's unsupported"

      return
    end

    puts "", "Importing upload references for #{type}..."

    content_uploads = query(<<~SQL)
      SELECT t.id AS target_id, u.value AS upload_id
        FROM #{type} t,
             JSON_EACH(t.upload_ids) u
       WHERE upload_ids IS NOT NULL
    SQL

    target_type = type.classify
    existing_upload_references =
      UploadReference.where(target_type: target_type).pluck(:upload_id, :target_id).to_set

    create_upload_references(content_uploads) do |row|
      upload_id = upload_id_from_original_id(row["upload_id"])
      target_id = content_id_from_original_id(type, row["target_id"])

      next unless upload_id && target_id
      next unless existing_upload_references.add?([upload_id, target_id])

      { upload_id: upload_id, target_type: target_type, target_id: target_id }
    end

    content_uploads.close
  end

  def content_id_from_original_id(type, original_id)
    case type
    when "posts"
      post_id_from_imported_id(original_id)
    when "chat_messages"
      chat_message_id_from_original_id(original_id)
    end
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
      tag_group = TagGroup.find_or_create_by!(name: row["name"])
      @tag_group_mapping[row["id"]] = tag_group.id

      if (permissions = row["permissions"])
        tag_group.permissions =
          JSON
            .parse(permissions)
            .map do |p|
              group_id = p["existing_group_id"] || group_id_from_imported_id(p["group_id"])
              group_id ? [group_id, p["permission_type"]] : nil
            end
            .compact
        tag_group.save!
      end
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
      tag =
        Tag.where("LOWER(name) = ?", cleaned_tag_name.downcase).first_or_create!(
          name: cleaned_tag_name,
        )
      @tag_mapping[row["id"]] = tag.id

      if row["tag_group_id"]
        TagGroupMembership.find_or_create_by!(
          tag_id: tag.id,
          tag_group_id: @tag_group_mapping[row["tag_group_id"]],
        )
      end
    end

    tags.close
  end

  def import_topic_tags
    puts "", "Importing topic tags..."

    if !@tag_mapping
      puts "  Skipping import of topic tags because tags have not been imported."
      return
    end

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

    unless defined?(::PostVoting)
      puts "  Skipping import of votes for posts because the plugin is not installed."
      return
    end

    votes = query(<<~SQL)
      SELECT *
        FROM votes
       WHERE votable_type = 'Post'
    SQL

    votable_type = "Post"
    existing_votes =
      PostVotingVote.where(votable_type: votable_type).pluck(:user_id, :votable_id).to_set

    create_post_voting_votes(votes) do |row|
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
                       FROM post_voting_votes
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

  def import_gamification_scores
    puts "", "Importing gamification scores..."

    unless defined?(::DiscourseGamification)
      puts "  Skipping import of gamification scores because the plugin is not installed."
      return
    end

    # TODO Make this configurable
    from_date = Date.today
    DiscourseGamification::GamificationLeaderboard.all.each do |leaderboard|
      leaderboard.update!(from_date: from_date)
    end

    scores = query(<<~SQL)
      SELECT *
        FROM gamification_score_events
       ORDER BY id
    SQL

    # TODO Better way of detecting existing scores?
    existing_scores = DiscourseGamification::GamificationScoreEvent.pluck(:user_id, :date).to_set

    create_gamification_score_events(scores) do |row|
      user_id = user_id_from_imported_id(row["user_id"])
      next unless user_id

      date = to_date(row["date"]) || from_date
      next if existing_scores.include?([user_id, date])

      {
        user_id: user_id,
        date: date,
        points: row["points"],
        description: row["description"],
        created_at: to_datetime(row["created_at"]),
      }
    end

    scores.close
  end

  def import_post_events
    puts "", "Importing events..."

    unless defined?(::DiscoursePostEvent)
      puts "  Skipping import of events because the plugin is not installed."
      return
    end

    post_events = query(<<~SQL)
      SELECT *
        FROM events
       ORDER BY id
    SQL

    default_custom_fields = "{}"
    timezone = "UTC"
    public_group_invitees = "{#{::DiscoursePostEvent::Event::PUBLIC_GROUP}}"
    standalone_invitees = "{}"

    existing_events = DiscoursePostEvent::Event.pluck(:id).to_set

    create_post_events(post_events) do |row|
      post_id = post_id_from_imported_id(row["post_id"])
      next if !post_id || existing_events.include?(post_id)

      {
        id: post_id,
        status: row["status"],
        original_starts_at: to_datetime(row["starts_at"]),
        original_ends_at: to_datetime(row["ends_at"]),
        name: row["name"],
        url: row["url"] ? row["url"][0..999] : nil,
        custom_fields: row["custom_fields"] || default_custom_fields,
        timezone: timezone,
        raw_invitees:
          (
            if row["status"] == ::DiscoursePostEvent::Event.statuses[:public]
              public_group_invitees
            else
              standalone_invitees
            end
          ),
      }
    end

    puts "", "Importing event dates..."

    post_events.reset
    existing_events = DiscoursePostEvent::EventDate.pluck(:event_id).to_set

    create_post_event_dates(post_events) do |row|
      post_id = post_id_from_imported_id(row["post_id"])
      next if !post_id || existing_events.include?(post_id)

      {
        event_id: post_id,
        starts_at: to_datetime(row["starts_at"]),
        ends_at: to_datetime(row["ends_at"]),
      }
    end

    puts "", "Importing topic event custom fields..."

    post_events.reset
    field_name = DiscoursePostEvent::TOPIC_POST_EVENT_STARTS_AT
    existing_fields = TopicCustomField.where(name: field_name).pluck(:topic_id).to_set

    create_topic_custom_fields(post_events) do |row|
      date = to_datetime(row["starts_at"])
      next unless date

      topic_id = topic_id_from_imported_post_id(row["post_id"])
      next if !topic_id || existing_fields.include?(topic_id)

      { topic_id: topic_id, name: field_name, value: date.utc.strftime("%Y-%m-%d %H:%M:%S") }
    end

    post_events.reset
    field_name = DiscoursePostEvent::TOPIC_POST_EVENT_ENDS_AT
    existing_fields = TopicCustomField.where(name: field_name).pluck(:topic_id).to_set

    create_topic_custom_fields(post_events) do |row|
      date = to_datetime(row["ends_at"])
      next unless date

      topic_id = topic_id_from_imported_post_id(row["post_id"])
      next if !topic_id || existing_fields.include?(topic_id)

      { topic_id: topic_id, name: field_name, value: date.utc.strftime("%Y-%m-%d %H:%M:%S") }
    end

    post_events.close
  end

  def import_tag_users
    puts "", "Importing tag users..."

    tag_users = query(<<~SQL)
      SELECT *
        FROM tag_users
       ORDER BY tag_id, user_id
    SQL

    existing_tag_users = TagUser.distinct.pluck(:user_id).to_set

    create_tag_users(tag_users) do |row|
      tag_id = @tag_mapping[row["tag_id"]]
      user_id = user_id_from_imported_id(row["user_id"])

      next unless tag_id && user_id
      next if existing_tag_users.include?(user_id)

      { tag_id: tag_id, user_id: user_id, notification_level: row["notification_level"] }
    end

    tag_users.close
  end

  def import_badge_groupings
    puts "", "Importing badge groupings..."

    rows = query(<<~SQL)
      SELECT DISTINCT badge_group
        FROM badges
       ORDER BY badge_group
    SQL

    @badge_group_mapping = {}
    max_position = BadgeGrouping.maximum(:position) || 0

    rows.each do |row|
      grouping =
        BadgeGrouping.find_or_create_by!(name: row["badge_group"]) do |bg|
          bg.position = max_position += 1
        end
      @badge_group_mapping[row["badge_group"]] = grouping.id
    end

    rows.close
  end

  def import_badges
    puts "", "Importing badges..."

    badges = query(<<~SQL)
      SELECT *
        FROM badges
       ORDER BY id
    SQL

    existing_badge_names = Badge.pluck(:name).to_set

    create_badges(badges) do |row|
      next if badge_id_from_original_id(row["id"]).present?

      badge_name = row["name"]
      unless existing_badge_names.add?(badge_name)
        badge_name = badge_name + "_1"
        badge_name.next! until existing_badge_names.add?(badge_name)
      end

      {
        original_id: row["id"],
        name: badge_name,
        description: row["description"],
        badge_type_id: row["badge_type_id"],
        badge_grouping_id: @badge_group_mapping[row["badge_group"]],
        long_description: row["long_description"],
        image_upload_id:
          row["image_upload_id"] ? upload_id_from_original_id(row["image_upload_id"]) : nil,
        query: row["query"],
        multiple_grant: to_boolean(row["multiple_grant"]),
        allow_title: to_boolean(row["allow_title"]),
        icon: row["icon"],
        listable: to_boolean(row["listable"]),
        target_posts: to_boolean(row["target_posts"]),
        enabled: to_boolean(row["enabled"]),
        auto_revoke: to_boolean(row["auto_revoke"]),
        trigger: row["trigger"],
        show_posts: to_boolean(row["show_posts"]),
      }
    end

    badges.close
  end

  def import_user_badges
    puts "", "Importing user badges..."

    user_badges = query(<<~SQL)
      SELECT user_id, badge_id, granted_at,
             ROW_NUMBER() OVER (PARTITION BY user_id, badge_id ORDER BY granted_at) - 1 AS seq
        FROM user_badges
       ORDER BY user_id, badge_id, granted_at
    SQL

    existing_user_badges = UserBadge.distinct.pluck(:user_id, :badge_id, :seq).to_set

    create_user_badges(user_badges) do |row|
      user_id = user_id_from_imported_id(row["user_id"])
      badge_id = badge_id_from_original_id(row["badge_id"])
      seq = row["seq"]

      next unless user_id && badge_id
      next if existing_user_badges.include?([user_id, badge_id, seq])

      { user_id: user_id, badge_id: badge_id, granted_at: to_datetime(row["granted_at"]), seq: seq }
    end

    user_badges.close

    puts "", "Updating badge grant counts..."
    start_time = Time.now

    DB.exec(<<~SQL)
        WITH
          grants AS (
                      SELECT badge_id, COUNT(*) AS grant_count FROM user_badges GROUP BY badge_id
                    )

      UPDATE badges
         SET grant_count = grants.grant_count
        FROM grants
       WHERE badges.id = grants.badge_id
         AND badges.grant_count <> grants.grant_count
    SQL

    puts "  Update took #{(Time.now - start_time).to_i} seconds."
  end

  def import_permalink_normalizations
    puts "", "Importing permalink normalizations..."

    start_time = Time.now

    rows = query(<<~SQL)
      SELECT normalization
        FROM permalink_normalizations
       ORDER BY normalization
    SQL

    normalizations = SiteSetting.permalink_normalizations
    normalizations = normalizations.blank? ? [] : normalizations.split("|")

    rows.each do |row|
      normalization = row["normalization"]
      normalizations << normalization if normalizations.exclude?(normalization)
    end

    SiteSetting.permalink_normalizations = normalizations.join("|")
    rows.close

    puts "  Import took #{(Time.now - start_time).to_i} seconds."
  end

  def import_permalinks
    puts "", "Importing permalinks..."

    rows = query(<<~SQL)
      SELECT *
        FROM permalinks
       ORDER BY url
    SQL

    existing_permalinks = Permalink.pluck(:url).to_set

    if !@tag_mapping
      puts "Skipping import of permalinks for tags because tags have not been imported."
    end

    create_permalinks(rows) do |row|
      next if existing_permalinks.include?(row["url"])

      if row["topic_id"]
        topic_id = topic_id_from_imported_id(row["topic_id"])
        next unless topic_id
        { url: row["url"], topic_id: topic_id }
      elsif row["post_id"]
        post_id = post_id_from_imported_id(row["post_id"])
        next unless post_id
        { url: row["url"], post_id: post_id }
      elsif row["category_id"]
        category_id = category_id_from_imported_id(row["category_id"])
        next unless category_id
        { url: row["url"], category_id: category_id }
      elsif row["tag_id"]
        next unless @tag_mapping
        tag_id = @tag_mapping[row["tag_id"]]
        next unless tag_id
        { url: row["url"], tag_id: tag_id }
      elsif row["user_id"]
        user_id = user_id_from_imported_id(row["user_id"])
        next unless user_id
        { url: row["url"], user_id: user_id }
      elsif row["external_url"]
        external_url = calculate_external_url(row)
        next unless external_url
        { url: row["url"], external_url: external_url }
      end
    end

    rows.close
  end

  def import_chat_direct_messages
    unless defined?(::Chat)
      puts "", "Skipping chat direct messages, because the chat plugin is not installed."
      return
    end

    puts "", "Importing chat direct messages..."

    direct_messages = query(<<~SQL)
      SELECT *
        FROM chat_channels
      WHERE chatable_type = 'DirectMessage'
        ORDER BY id
    SQL

    create_chat_direct_message(direct_messages) do |row|
      next if chat_direct_message_channel_id_from_original_id(row["chatable_id"]).present?

      {
        original_id: row["chatable_id"],
        created_at: to_datetime(row["created_at"]),
        group: to_boolean(row["is_group"]),
      }
    end

    direct_messages.close
  end

  def import_chat_channels
    unless defined?(::Chat)
      puts "", "Skipping chat channels, because the chat plugin is not installed."
      return
    end

    puts "", "Importing chat channels..."

    # Ideally, we’d like these to be set in `import_site_settings`,
    # but since there’s no way to enforce that, we're defaulting to keeping all chats
    # indefinitely for now
    SiteSetting.chat_channel_retention_days = 0
    SiteSetting.chat_dm_retention_days = 0

    channels = query(<<~SQL)
      SELECT *
        FROM chat_channels
       ORDER BY id
    SQL

    create_chat_channels(channels) do |row|
      next if chat_channel_id_from_original_id(row["id"]).present?

      case row["chatable_type"]
      when "Category"
        type = "CategoryChannel"
        chatable_id = category_id_from_imported_id(row["chatable_id"])
      when "DirectMessage"
        chatable_id = chat_direct_message_channel_id_from_original_id(row["chatable_id"])
        type = "DirectMessageChannel"
      end

      next if !chatable_id
      # TODO: Add more uniqueness checks
      #       Ensure no channel with same name and category exists?

      {
        original_id: row["id"],
        name: row["name"],
        description: row["description"],
        slug: row["slug"],
        status: row["status"],
        chatable_id: chatable_id,
        chatable_type: row["chatable_type"],
        user_count: row["user_count"],
        messages_count: row["messages_count"],
        type: type,
        created_at: to_datetime(row["created_at"]),
        allow_channel_wide_mentions: to_boolean(row["allow_channel_wide_mentions"]),
        auto_join_users: to_boolean(row["auto_join_users"]),
        threading_enabled: to_boolean(row["threading_enabled"]),
      }
    end

    channels.close
  end

  def import_user_chat_channel_memberships
    unless defined?(::Chat)
      puts "", "Skipping user chat channel memberships, because the chat plugin is not installed."
      return
    end

    puts "", "Importing user chat channel memberships..."

    channel_users = query(<<~SQL)
      SELECT chat_channels.chatable_type, chat_channels.chatable_id, chat_channel_users.*
        FROM chat_channel_users
             JOIN chat_channels ON chat_channels.id = chat_channel_users.chat_channel_id
       ORDER BY chat_channel_users.chat_channel_id
    SQL

    existing_members =
      Chat::UserChatChannelMembership.distinct.pluck(:user_id, :chat_channel_id).to_set

    create_user_chat_channel_memberships(channel_users) do |row|
      user_id = user_id_from_imported_id(row["user_id"])
      channel_id = chat_channel_id_from_original_id(row["chat_channel_id"])
      last_read_message_id = chat_message_id_from_original_id(row["last_read_message_id"])

      next if user_id.blank? || channel_id.blank?
      next unless existing_members.add?([user_id, channel_id])

      # `last_viewed_at` is required, if not provided, set a placeholder,
      # it'll be updated in the `update_chat_membership_metadata` step
      last_viewed_at = to_datetime(row["last_viewed_at"].presence || LAST_VIEWED_AT_PLACEHOLDER)

      {
        user_id: user_id,
        chat_channel_id: channel_id,
        created_at: to_datetime(row["created_at"]),
        following: to_boolean(row["following"]),
        muted: to_boolean(row["muted"]),
        desktop_notification_level: row["desktop_notification_level"],
        mobile_notification_level: row["mobile_notification_level"],
        last_read_message_id: last_read_message_id,
        join_mode: row["join_mode"],
        last_viewed_at: last_viewed_at,
      }
    end

    puts "", "Importing chat direct message users..."

    channel_users.reset
    existing_direct_message_users =
      Chat::DirectMessageUser.distinct.pluck(:direct_message_channel_id, :user_id).to_set

    create_direct_message_users(channel_users) do |row|
      next if row["chatable_type"] != "DirectMessage"

      user_id = user_id_from_imported_id(row["user_id"])
      direct_message_channel_id =
        chat_direct_message_channel_id_from_original_id(row["chatable_id"])

      next if user_id.blank? || direct_message_channel_id.blank?
      next unless existing_direct_message_users.add?([direct_message_channel_id, user_id])

      {
        direct_message_channel_id: direct_message_channel_id,
        user_id: user_id,
        created_at: to_datetime(row["created_at"]),
      }
    end

    channel_users.close
  end

  def import_chat_threads
    unless defined?(::Chat)
      puts "", "Skipping chat threads, because the chat plugin is not installed."
      return
    end

    puts "", "Importing chat threads..."

    threads = query(<<~SQL)
      SELECT *
      FROM chat_threads
      ORDER BY chat_channel_id, id
    SQL

    create_chat_threads(threads) do |row|
      channel_id = chat_channel_id_from_original_id(row["chat_channel_id"])
      original_message_user_id = user_id_from_imported_id(row["original_message_user_id"])

      next if channel_id.blank? || original_message_user_id.blank?

      # Messages aren't imported yet. Use a placeholder `original_message_id` for now.
      # Actual original_message_ids will be set later after messages have been imported
      placeholder_original_message_id = -1

      {
        original_id: row["id"],
        channel_id: channel_id,
        original_message_id: placeholder_original_message_id,
        original_message_user_id: original_message_user_id,
        status: row["status"],
        title: row["title"],
        created_at: to_datetime(row["created_at"]),
        replies_count: row["replies_count"],
      }
    end

    threads.close
  end

  def import_chat_thread_users
    unless defined?(::Chat)
      puts "", "Skipping chat thread users, because the chat plugin is not installed."
      return
    end

    thread_users = query(<<~SQL)
      SELECT *
      FROM chat_thread_users
      ORDER BY chat_thread_id, user_id
    SQL

    puts "", "Importing chat thread users..."

    existing_members = Chat::UserChatThreadMembership.distinct.pluck(:user_id, :thread_id).to_set

    create_thread_users(thread_users) do |row|
      user_id = user_id_from_imported_id(row["user_id"])
      thread_id = chat_thread_id_from_original_id(row["chat_thread_id"])
      last_read_message_id = chat_message_id_from_original_id(row["last_read_message_id"])

      next if user_id.blank? || thread_id.blank?
      next unless existing_members.add?([user_id, thread_id])

      {
        user_id: user_id,
        thread_id: thread_id,
        notification_level: row["notification_level"],
        created_at: to_datetime(row["created_at"]),
        last_read_message_id: last_read_message_id,
      }
    end

    thread_users.close
  end

  def import_chat_messages
    unless defined?(::Chat)
      puts "", "Skipping chat messages, because the chat plugin is not installed."
      return
    end

    puts "", "Importing chat messages..."

    messages = query(<<~SQL)
      SELECT *
      FROM chat_messages
      ORDER BY chat_channel_id, created_at, id
    SQL

    create_chat_messages(messages) do |row|
      channel_id = chat_channel_id_from_original_id(row["chat_channel_id"])
      user_id = user_id_from_imported_id(row["user_id"])

      next if channel_id.blank? || user_id.blank?
      next if row["message"].blank? && row["upload_ids"].blank?

      last_editor_id = user_id_from_imported_id(row["last_editor_id"])
      thread_id = chat_thread_id_from_original_id(row["thread_id"])
      deleted_by_id = user_id_from_imported_id(row["deleted_by_id"])
      in_reply_to_id = chat_message_id_from_original_id(row["in_reply_to_id"]) # TODO: this will only work if serial ids are used

      {
        original_id: row["id"],
        chat_channel_id: channel_id,
        user_id: user_id,
        thread_id: thread_id,
        last_editor_id: last_editor_id,
        created_at: to_datetime(row["created_at"]),
        deleted_at: to_datetime(row["deleted_at"]),
        deleted_by_id: deleted_by_id,
        in_reply_to_id: in_reply_to_id,
        message: raw_with_placeholders_interpolated(row["message"], row),
      }
    end

    messages.close
  end

  def import_chat_reactions
    unless defined?(::Chat)
      puts "", "Skipping chat message reactions, because the chat plugin is not installed."
      return
    end

    puts "", "Importing chat message reactions..."

    reactions = query(<<~SQL)
      SELECT *
      FROM chat_reactions
      ORDER BY chat_message_id
    SQL

    existing_reactions =
      Chat::MessageReaction.distinct.pluck(:chat_message_id, :user_id, :emoji).to_set

    create_chat_message_reactions(reactions) do |row|
      next if row["emoji"].blank?

      message_id = chat_message_id_from_original_id(row["chat_message_id"])
      user_id = user_id_from_imported_id(row["user_id"])

      next if message_id.blank? || user_id.blank?
      next unless existing_reactions.add?([message_id, user_id, row["emoji"]])

      # TODO: Validate emoji

      {
        chat_message_id: message_id,
        user_id: user_id,
        emoji: row["emoji"],
        created_at: to_datetime(row["created_at"]),
      }
    end

    reactions.close
  end

  def import_chat_mentions
    unless defined?(::Chat)
      puts "", "Skipping chat mentions, because the chat plugin is not installed."
      return
    end

    puts "", "Importing chat mentions..."

    mentions = query(<<~SQL)
      SELECT *
      FROM chat_mentions
      ORDER BY chat_message_id
    SQL

    create_chat_mentions(mentions) do |row|
      # TODO: Maybe standardize mention types, instead of requiring converter
      # to set namespaced ruby classes
      chat_message_id = chat_message_id_from_original_id(row["chat_message_id"])
      target_id =
        case row["type"]
        when "Chat::AllMention", "Chat::HereMention"
          nil
        when "Chat::UserMention"
          user_id_from_imported_id(row["target_id"])
        when "Chat::GroupMention"
          group_id_from_imported_id(row["target_id"])
        end

      next if target_id.nil? && %w[Chat::AllMention Chat::HereMention].exclude?(row["type"])

      {
        chat_message_id: chat_message_id,
        target_id: target_id,
        type: row["type"],
        created_at: to_datetime(row["created_at"]),
      }
    end

    mentions.close
  end

  def update_chat_threads
    unless defined?(::Chat)
      puts "", "Skipping chat thread updates, because the chat plugin is not installed."
      return
    end

    puts "", "Updating chat threads..."

    start_time = Time.now

    DB.exec(<<~SQL)
      WITH thread_info AS (
        SELECT
          thread_id,
          MIN(id) AS original_message_id,
          COUNT(id) - 1 AS replies_count,
          MAX(id) AS last_message_id
        FROM
          chat_messages
        WHERE
          thread_id IS NOT NULL
        GROUP BY
          thread_id
      )
      UPDATE chat_threads
      SET
        original_message_id = thread_info.original_message_id,
        replies_count = thread_info.replies_count,
        last_message_id = thread_info.last_message_id
      FROM
        thread_info
      WHERE
        chat_threads.id = thread_info.thread_id;
    SQL

    puts "  Update took #{(Time.now - start_time).to_i} seconds."
  end

  def update_chat_membership_metadata
    unless defined?(::Chat)
      puts "",
           "Skipping chat membership metadata updates, because the chat plugin is not installed."
      return
    end

    puts "", "Updating chat membership metadata..."

    start_time = Time.now

    # Ensure the user is caught up on all messages in the channel. The primary aim is to prevent
    # new message indicators from showing up for imported messages. We do this by updating
    # the `last_viewed_at` and `last_read_message_id` columns in `user_chat_channel_memberships`
    # if they were not imported.
    DB.exec(<<~SQL)
      WITH latest_messages AS (
        SELECT
          chat_channel_id,
          MAX(id) AS last_message_id,
          MAX(created_at) AS last_message_created_at
        FROM chat_messages
        WHERE thread_id IS NULL
        GROUP BY chat_channel_id
      )
      UPDATE user_chat_channel_memberships uccm
      SET
        last_read_message_id = COALESCE(uccm.last_read_message_id, lm.last_message_id),
        last_viewed_at = CASE
                           WHEN uccm.last_viewed_at = '#{LAST_VIEWED_AT_PLACEHOLDER}'
                           THEN lm.last_message_created_at + INTERVAL '1 second'
                           ELSE uccm.last_viewed_at
                         END
      FROM latest_messages lm
      WHERE uccm.chat_channel_id = lm.chat_channel_id
    SQL

    # Set `last_read_message_id` in `user_chat_thread_memberships` if none is provided.
    # Similar to the chat channel membership update above, this ensures the user is caught up on messages in the thread.
    DB.exec(<<~SQL)
      WITH latest_thread_messages AS (
        SELECT
            thread_id,
            MAX(id) AS last_message_id
        FROM chat_messages
        WHERE thread_id IS NOT NULL
        GROUP BY thread_id
      )
      UPDATE user_chat_thread_memberships utm
      SET
        last_read_message_id = ltm.last_message_id
      FROM latest_thread_messages ltm
      WHERE utm.thread_id = ltm.thread_id
        AND utm.last_read_message_id IS NULL
    SQL

    puts "  Update took #{(Time.now - start_time).to_i} seconds."
  end

  def calculate_external_url(row)
    external_url = row["external_url"].dup
    placeholders = row["external_url_placeholders"]&.then { |json| JSON.parse(json) }
    return external_url unless placeholders

    placeholders.each do |placeholder|
      case placeholder["type"]
      when "category_url"
        category_id = category_id_from_imported_id(placeholder["id"])
        category = Category.find(category_id)
        external_url.gsub!(
          placeholder["placeholder"],
          "c/#{category.slug_path.join("/")}/#{category.id}",
        )
      when "category_slug_ref"
        category_id = category_id_from_imported_id(placeholder["id"])
        category = Category.find(category_id)
        external_url.gsub!(placeholder["placeholder"], category.slug_ref)
      when "tag_name"
        if @tag_mapping
          tag_id = @tag_mapping[placeholder["id"]]
          tag = Tag.find(tag_id)
          external_url.gsub!(placeholder["placeholder"], tag.name)
        end
      else
        raise "Unknown placeholder type: #{placeholder[:type]}"
      end
    end

    external_url
  end

  def create_connection(path)
    sqlite = SQLite3::Database.new(path, results_as_hash: true)
    sqlite.busy_timeout = 60_000 # 60 seconds
    sqlite.journal_mode = "wal"
    sqlite.synchronous = "normal"
    sqlite
  end

  def query(sql, *bind_vars, db: @source_db)
    result_set = db.prepare(sql).execute(*bind_vars)

    if block_given?
      result = yield result_set
      result_set.close
      result
    else
      result_set
    end
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

  def anon_username_suffix
    while true
      suffix = (SecureRandom.random_number * 100_000_000).to_i
      break if @anonymized_user_suffixes.exclude?(suffix)
    end

    @anonymized_user_suffixes << suffix
    suffix
  end
end

BulkImport::Generic.new(ARGV[0], ARGV[1]).start

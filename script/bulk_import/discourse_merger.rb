# frozen_string_literal: true

require_relative "base"

class BulkImport::DiscourseMerger < BulkImport::Base
  NOW = "now()"
  CUSTOM_FIELDS = %w[category group post topic user]

  # DB_NAME: name of database being merged into the current local db
  # DB_HOST: hostname of database being merged
  # DB_PASS: password used to access the Discourse database by the postgres user
  # UPLOADS_PATH: absolute path of the directory containing "original"
  #               and "optimized" dirs. e.g. /home/discourse/other-site/public/uploads/default
  # SOURCE_BASE_URL: base url of the site being merged. e.g. https://meta.discourse.org
  # SOURCE_CDN: (optional) base url of the CDN of the site being merged.
  #             e.g. https://discourse-cdn-sjc1.com/business4

  def initialize
    db_password = ENV["DB_PASS"] || "import_password"
    local_db = ActiveRecord::Base.connection_db_config.configuration_hash
    @raw_connection =
      PG.connect(
        dbname: local_db[:database],
        host: "localhost",
        port: local_db[:port],
        user: "postgres",
        password: db_password,
      )

    @source_db_config = {
      dbname: ENV["DB_NAME"] || "dd_demo",
      host: ENV["DB_HOST"] || "localhost",
      user: "postgres",
      password: db_password,
    }

    raise "SOURCE_BASE_URL missing!" unless ENV["SOURCE_BASE_URL"]

    @source_base_url = ENV["SOURCE_BASE_URL"]
    @uploads_path = ENV["UPLOADS_PATH"]
    @uploader = ImportScripts::Uploader.new

    @source_cdn = ENV["SOURCE_CDN"] if ENV["SOURCE_CDN"]

    local_version = @raw_connection.exec("select max(version) from schema_migrations")
    local_version = local_version.first["max"]
    source_version = source_raw_connection.exec("select max(version) from schema_migrations")
    source_version = source_version.first["max"]

    if local_version != source_version
      raise "DB schema mismatch. Databases must be at the same migration version. Local is #{local_version}, other is #{source_version}"
    end

    @encoder = PG::TextEncoder::CopyRow.new

    @merged_user_ids = []
    @tags = {}
    @tag_groups = {}
    @uploads = {}
    @post_actions = {}
    @notifications = {}
    @badge_groupings = {}
    @badges = {}
    @email_tokens = {}
    @polls = {}
    @poll_options = {}
    @avatars = {}

    @auto_group_ids = Group::AUTO_GROUPS.values

    # add your authorized extensions here:
    SiteSetting.authorized_extensions = %w[jpg jpeg png gif].join("|")

    @sequences = {}
  end

  def start
    run
  ensure
    @raw_connection&.close
    source_raw_connection&.close
  end

  def execute
    @first_new_user_id = @last_user_id + 1
    @first_new_topic_id = @last_topic_id + 1

    copy_users
    copy_uploads if @uploads_path
    copy_user_stuff
    copy_search_data
    copy_groups
    copy_categories_with_no_parent
    copy_categories_first_child
    update_category_settings
    copy_topics
    copy_posts
    copy_upload_references
    copy_tags

    copy_everything_else
    copy_badges
    copy_solutions
    copy_solved
    # TO-DO: copy_assignments

    fix_user_columns
    fix_category_descriptions
    fix_polls
    fix_featured_topic
    fix_user_upload
  end

  def source_raw_connection
    @source_raw_connection ||= PG.connect(@source_db_config)
  end

  def copy_users
    puts "", "merging users..."

    imported_ids = []

    usernames_lower = User.unscoped.pluck(:username_lower).to_set

    columns = User.columns.map(&:name)
    sql = "COPY users (#{columns.map { |c| "\"#{c}\"" }.join(",")}) FROM STDIN"

    @raw_connection.copy_data(sql, @encoder) do
      source_raw_connection
        .exec(
          "SELECT #{columns.map { |c| "u.\"#{c}\"" }.join(",")}, e.email FROM users u INNER JOIN user_emails e ON (u.id = e.user_id AND e.primary = TRUE) WHERE u.id > 0",
        )
        .each do |row|
          old_user_id = row["id"]&.to_i
          if existing = UserEmail.where(email: row.delete("email")).first&.user
            # Merge these users
            @users[old_user_id] = existing.id
            @merged_user_ids << old_user_id
            next
          else
            # New user
            unless usernames_lower.add?(row["username_lower"])
              username = row["username"] + "_1"
              username.next! until usernames_lower.add?(username.downcase)
              row["username"] = username
              row["username_lower"] = row["username"].downcase
            end

            row["id"] = (@last_user_id += 1)
            @users[old_user_id] = row["id"]

            @raw_connection.put_copy_data row.values
          end
          imported_ids << old_user_id
        end
    end

    @sequences[User.sequence_name] = @last_user_id + 1 if @last_user_id

    create_custom_fields("user", "id", imported_ids) do |old_user_id|
      { value: old_user_id, record_id: user_id_from_imported_id(old_user_id) }
    end

    copy_model(
      EmailToken,
      skip_if_merged: true,
      is_a_user_model: true,
      skip_processing: true,
      mapping: @email_tokens,
    )

    copy_model(UserEmail, skip_if_merged: true, is_a_user_model: true, skip_processing: true)
  end

  def copy_user_stuff
    copy_model(UserProfile, skip_if_merged: true, is_a_user_model: true, skip_processing: true)

    [
      UserStat,
      UserOption,
      UserVisit,
      GivenDailyLike,
      UserSecondFactor,
      PushSubscription,
      DoNotDisturbTiming,
    ].each { |c| copy_model(c, skip_if_merged: true, is_a_user_model: true, skip_processing: true) }

    [MutedUser, IgnoredUser].each { |c| copy_model(c, is_a_user_model: true) }

    [
      UserAssociatedAccount,
      Oauth2UserInfo,
      SingleSignOnRecord,
      EmailChangeRequest,
      UserProfileView,
    ].each { |c| copy_model(c, skip_if_merged: true, is_a_user_model: true) }

    copy_model(UserAvatar, skip_if_merged: true, is_a_user_model: true, mapping: @avatars)
  end

  def copy_search_data
    [UserSearchData].each do |c|
      copy_model_user_search_data(
        c,
        skip_if_merged: true,
        is_a_user_model: true,
        skip_processing: true,
      )
    end
  end

  def copy_groups
    copy_model(
      Group,
      mapping: @groups,
      skip_processing: true,
      select_sql: merge_same_named_rows(Group, @groups, where: "automatic = false"),
    )

    copy_model(GroupUser, skip_if_merged: true)
  end

  # Maps source rows onto destination rows with the same case-insensitive name,
  # because copying them would violate the unique name index. Returns the SQL
  # that selects the remaining source rows for copying.
  def merge_same_named_rows(klass, mapping, where: "TRUE")
    existing_ids = klass.unscoped.pluck(:name, :id).to_h { |name, id| [name.downcase, id] }
    merged_ids = []

    source_raw_connection
      .exec("SELECT id, name FROM #{klass.table_name} WHERE #{where}")
      .each do |row|
        next unless existing_id = existing_ids[row["name"].downcase]
        mapping[row["id"].to_i] = existing_id
        merged_ids << row["id"].to_i
      end

    sql = +"SELECT #{klass.columns.map { |c| "\"#{c.name}\"" }.join(", ")} FROM #{klass.table_name}"
    sql << " WHERE #{where}"
    sql << " AND id NOT IN (#{merged_ids.join(", ")})" if merged_ids.any?
    sql
  end

  def category_exists(cat_row)
    # Categories with the same name/slug and parent are merged

    parent = category_id_from_imported_id(cat_row["parent_category_id"])
    existing = Category.where(slug: cat_row["slug"]).or(Category.where(name: cat_row["name"])).first

    existing.id if existing && parent == existing&.parent_category_id
  end

  def copy_categories_with_no_parent
    # Categories with no parent are copied first so child categories can reference the parent
    puts "merging categories..."

    columns = Category.columns.map(&:name)
    imported_ids = []
    last_id = Category.unscoped.maximum(:id) || 1

    sql = "COPY categories (#{columns.map { |c| "\"#{c}\"" }.join(", ")}) FROM STDIN"
    @raw_connection.copy_data(sql, @encoder) do
      source_raw_connection
        .exec(
          "SELECT #{columns.map { |c| "c.\"#{c}\"" }.join(", ")}
             FROM categories c
             WHERE parent_category_id IS NULL",
        )
        .each do |row|
          # If a category with the same slug or name, and the same parent, exists
          existing_category = category_exists(row)

          if existing_category
            @categories[row["id"].to_i] = existing_category
            next
          end

          existing_slug = Category.where(slug: row["slug"]).first
          if existing_slug
            # We still need to avoid a unique index conflict on the slug when importing
            # if that's the case, we'll append the imported id
            row["slug"] = "#{row["slug"]}-#{row["id"]}"
          end

          old_user_id = row["user_id"].to_i
          row["user_id"] = user_id_from_imported_id(old_user_id) || -1 if old_user_id >= 1

          row["reviewable_by_group_id"] = group_id_from_imported_id(
            row["reviewable_by_group_id"],
          ) if row["reviewable_by_group_id"]

          old_id = row["id"].to_i
          row["id"] = (last_id += 1)
          imported_ids << old_id
          @categories[old_id] = row["id"]

          @raw_connection.put_copy_data(row.values)
        end
    end

    @sequences[Category.sequence_name] = last_id + 1

    create_custom_fields("category", "id", imported_ids) do |imported_id|
      { record_id: category_id_from_imported_id(imported_id), value: imported_id }
    end
  end

  def copy_categories_first_child
    # Only for categories with one parent, no granparent
    puts "merging categories..."

    columns = Category.columns.map(&:name)
    imported_ids = []
    last_id = Category.unscoped.maximum(:id) || 1

    sql = "COPY categories (#{columns.map { |c| "\"#{c}\"" }.join(", ")}) FROM STDIN"
    @raw_connection.copy_data(sql, @encoder) do
      source_raw_connection
        .exec(
          "SELECT #{columns.map { |c| "c.\"#{c}\"" }.join(", ")}
             FROM categories c
             WHERE parent_category_id IS NOT NULL",
        )
        .each do |row|
          # If a category with the same slug or name, and the same parent, exists
          existing_category = category_exists(row)

          if existing_category
            @categories[row["id"].to_i] = existing_category
            next
          end

          existing_slug = Category.where(slug: row["slug"]).first
          if existing_slug
            # We still need to avoid a unique index conflict on the slug when importing
            # if that's the case, we'll append the imported id
            row["slug"] = "#{row["slug"]}-#{row["id"]}"
          end

          old_user_id = row["user_id"].to_i
          row["user_id"] = user_id_from_imported_id(old_user_id) || -1 if old_user_id >= 1

          row["parent_category_id"] = category_id_from_imported_id(row["parent_category_id"])

          row["reviewable_by_group_id"] = group_id_from_imported_id(
            row["reviewable_by_group_id"],
          ) if row["reviewable_by_group_id"]

          old_id = row["id"].to_i
          row["id"] = (last_id += 1)
          imported_ids << old_id
          @categories[old_id] = row["id"]

          @raw_connection.put_copy_data(row.values)
        end
    end

    @sequences[Category.sequence_name] = last_id + 1

    create_custom_fields("category", "id", imported_ids) do |imported_id|
      { record_id: category_id_from_imported_id(imported_id), value: imported_id }
    end
  end

  def fix_category_descriptions
    puts "updating category description topic ids..."

    @categories.each_value do |new_id|
      next if !CategoryCustomField.where(category_id: new_id, name: "import_id").exists?
      category = Category.find_by(id: new_id)
      next if category&.topic_id.nil?

      # Rows are copied verbatim from the source site and may not pass current
      # validations, so only the remapped column is written.
      if description_topic_id = topic_id_from_imported_id(category.topic_id)
        category.update_columns(topic_id: description_topic_id)
      end
    end
  end

  def update_category_settings
    puts "Updating category settings..."
    sql = "SELECT * FROM category_settings"
    output = source_raw_connection.exec(sql)
    output.each do |row|
      category_id = category_id_from_imported_id(row["category_id"])
      next unless category_id
      category = Category.find_by_id(category_id)
      next if category.name == "Uncategorized"
      category_settings = category.category_setting
      next unless category_settings
      category_settings.num_auto_bump_daily = row["num_auto_bump_daily"]
      category_settings.auto_bump_cooldown_days = row["auto_bump_cooldown_days"]
      category_settings.save!
    end
  end

  def copy_topics
    copy_model(Topic, mapping: @topics)
    [
      TopicAllowedGroup,
      TopicAllowedUser,
      TopicEmbed,
      TopicSearchData,
      TopicTimer,
      TopicUser,
      TopicViewItem,
    ].each { |k| copy_model(k, skip_processing: false) }
  end

  def copy_posts
    copy_model(Post, skip_processing: false, mapping: @posts)
    copy_model(PostAction, mapping: @post_actions)
    [PostReply, TopicLink, UserAction, QuotedPost].each { |k| copy_model(k) }
    [PostStat, IncomingEmail, PostDetail, PostRevision].each do |k|
      copy_model(k, skip_processing: true)
    end
  end

  def copy_tags
    puts "merging tags..."

    columns = Tag.columns.map(&:name)
    imported_ids = []
    last_id = Tag.unscoped.maximum(:id) || 1

    sql = "COPY tags (#{columns.map { |c| "\"#{c}\"" }.join(", ")}) FROM STDIN"
    @raw_connection.copy_data(sql, @encoder) do
      source_raw_connection
        .exec("SELECT #{columns.map { |c| "\"#{c}\"" }.join(", ")} FROM tags")
        .each do |row|
          if existing = Tag.where_name(row["name"]).first
            @tags[row["id"]] = existing.id
            next
          end

          old_id = row["id"]
          row["id"] = (last_id += 1)
          @tags[old_id.to_s] = row["id"]
          row["target_tag_id"] = row["id"]

          @raw_connection.put_copy_data(row.values)
        end
    end

    @sequences[Tag.sequence_name] = last_id + 1

    [TagUser, TopicTag, CategoryTag, CategoryTagStat].each { |k| copy_model(k) }
    copy_model(
      TagGroup,
      mapping: @tag_groups,
      select_sql: merge_same_named_rows(TagGroup, @tag_groups),
    )
    [TagGroupMembership, CategoryTagGroup, CategoryRequiredTagGroup].each { |k| copy_model(k) }

    col_list = TagGroupPermission.columns.map { |c| "\"#{c.name}\"" }.join(", ")
    copy_model(
      TagGroupPermission,
      select_sql:
        "SELECT #{col_list} FROM tag_group_permissions WHERE group_id NOT IN (#{@auto_group_ids.join(", ")})",
    )
  end

  def copy_uploads
    puts ""
    print "copying uploads..."

    FileUtils.cp_r(File.join(@uploads_path, "."), Rails.public_path.join("uploads/default").to_s)

    columns = Upload.columns.map(&:name)
    last_id = Upload.unscoped.maximum(:id) || 1
    sql = "COPY uploads (#{columns.map { |c| "\"#{c}\"" }.join(", ")}) FROM STDIN"
    existing_ids_by_sha1 = Upload.unscoped.where.not(sha1: nil).pluck(:sha1, :id).to_h

    @raw_connection.copy_data(sql, @encoder) do
      source_raw_connection
        .exec("SELECT #{columns.map { |c| "\"#{c}\"" }.join(", ")} FROM uploads")
        .each do |row|
          if existing_id = existing_ids_by_sha1[row["sha1"]]
            @uploads[row["id"].to_s] = existing_id
            next
          end

          # make sure to get a backup with uploads then convert them to local.
          # when the backup is restored to a site with s3 uploads, it will upload the items
          # to the bucket
          rel_filename = row["url"].gsub(%r{^/uploads/[^/]+/}, "")
          # assumes if coming from amazonaws.com that we want to remove everything
          # but the text after the last `/`, which should leave us the filename
          rel_filename = rel_filename.gsub(%r{^//[^/]+\.amazonaws\.com/\S+uploads/[^/]+/}, "")
          absolute_filename = File.join(@uploads_path, rel_filename)

          old_id = row["id"]
          if old_id && last_id
            row["id"] = (last_id += 1)
            @uploads[old_id.to_s] = row["id"]
          end

          old_user_id = row["user_id"].to_i
          if old_user_id >= 1
            row["user_id"] = user_id_from_imported_id(old_user_id)
            next if row["user_id"].nil?
          end

          row["url"] = "/uploads/default/#{rel_filename}" if File.exist?(absolute_filename)
          @raw_connection.put_copy_data(row.values)
        end
    end

    @sequences[Upload.sequence_name] = last_id + 1
  end

  def copy_upload_references
    puts ""
    print "copying upload references..."
    copy_model(UploadReference)
  end

  def copy_everything_else
    [PostTiming, UserArchivedMessage, UnsubscribeKey, GroupMention, Bookmark].each do |k|
      copy_model(k, skip_processing: true)
    end

    [UserHistory, UserWarning, GroupArchivedMessage, CategoryUser, UserUpload].each do |k|
      copy_model(k)
    end

    copy_model(Notification, mapping: @notifications)

    copy_model(Poll, mapping: @polls)
    copy_model(PollOption, mapping: @poll_options)
    copy_model(PollVote)

    [
      CategoryGroup,
      GroupHistory,
      GroupTagNotificationDefault,
      GroupCategoryNotificationDefault,
    ].each do |k|
      col_list = k.columns.map { |c| "\"#{c.name}\"" }.join(", ")
      copy_model(
        k,
        select_sql:
          "SELECT #{col_list} FROM #{k.table_name} WHERE group_id NOT IN (#{@auto_group_ids.join(", ")})",
      )
    end

    [
      CategoryFeaturedTopic,
      CategoryFormTemplate,
      CategoryPostingReviewGroup,
      CategorySearchData,
    ].each { |k| copy_model(k) }

    # Copy custom fields
    [CategoryCustomField].each do |k|
      col_list = k.columns.map { |c| "\"#{c.name}\"" }.join(", ")
      copy_model(k, select_sql: "SELECT #{col_list} FROM #{k.table_name} WHERE name != 'import_id'")
    end
  end

  def copy_badges
    copy_model(BadgeGrouping, mapping: @badge_groupings, skip_processing: true)

    puts "merging badges..."
    columns = Badge.columns.map(&:name)
    imported_ids = []
    last_id = Badge.unscoped.maximum(:id) || 1

    sql = "COPY badges (#{columns.map { |c| "\"#{c}\"" }.join(", ")}) FROM STDIN"
    @raw_connection.copy_data(sql, @encoder) do
      source_raw_connection
        .exec("SELECT #{columns.map { |c| "\"#{c}\"" }.join(", ")} FROM badges")
        .each do |row|
          if existing = Badge.where(name: row["name"]).first
            @badges[row["id"]] = existing.id
            next
          end

          old_id = row["id"]
          row["id"] = (last_id += 1)
          @badges[old_id.to_s] = row["id"]

          row["badge_grouping_id"] = @badge_groupings[row["badge_grouping_id"]] if row[
            "badge_grouping_id"
          ]

          row["image_upload_id"] = upload_id_from_imported_id(row["image_upload_id"])

          @raw_connection.put_copy_data(row.values)
        end
    end

    @sequences[Badge.sequence_name] = last_id + 1

    copy_model(UserBadge, is_a_user_model: true)
  end

  def copy_solutions
    puts "merging solution posts..."
    columns = PostCustomField.columns.map(&:name)
    last_id = PostCustomField.unscoped.maximum(:id) || 1

    sql = "COPY post_custom_fields (#{columns.map { |c| "\"#{c}\"" }.join(", ")}) FROM STDIN"
    @raw_connection.copy_data(sql, @encoder) do
      source_raw_connection
        .exec(
          "SELECT #{columns.map { |c| "\"#{c}\"" }.join(", ")} FROM post_custom_fields WHERE name = 'is_accepted_answer'",
        )
        .each do |row|
          row["id"] = (last_id += 1)
          row["post_id"] = post_id_from_imported_id(row["post_id"])
          next unless row["post_id"]

          @raw_connection.put_copy_data(row.values)
        end
    end

    @sequences[PostCustomField.sequence_name] = last_id + 1 if last_id
  end

  def copy_solved
    puts "merging solved topics..."
    columns = TopicCustomField.columns.map(&:name)
    last_id = TopicCustomField.unscoped.maximum(:id) || 1

    sql = "COPY topic_custom_fields (#{columns.map { |c| "\"#{c}\"" }.join(", ")}) FROM STDIN"
    @raw_connection.copy_data(sql, @encoder) do
      source_raw_connection
        .exec(
          "SELECT #{columns.map { |c| "\"#{c}\"" }.join(", ")} FROM topic_custom_fields WHERE name = 'accepted_answer_post_id'",
        )
        .each do |row|
          row["id"] = (last_id += 1)
          row["topic_id"] = topic_id_from_imported_id(row["topic_id"])
          row["value"] = post_id_from_imported_id(row["value"])

          next unless row["topic_id"]

          @raw_connection.put_copy_data(row.values)
        end
    end

    @sequences[TopicCustomField.sequence_name] = last_id + 1 if last_id
  end

  def copy_model(
    klass,
    skip_if_merged: false,
    is_a_user_model: false,
    skip_processing: false,
    mapping: nil,
    select_sql: nil
  )
    puts "copying #{klass.table_name}..."

    columns = klass.columns.map(&:name)
    has_custom_fields = CUSTOM_FIELDS.include?(klass.name.downcase)
    imported_ids = []
    last_id = columns.include?("id") ? (klass.unscoped.maximum(:id) || 1) : nil

    sql = "COPY #{klass.table_name} (#{columns.map { |c| "\"#{c}\"" }.join(", ")}) FROM STDIN"
    @raw_connection.copy_data(sql, @encoder) do
      source_raw_connection
        .exec(
          select_sql ||
            "SELECT #{columns.map { |c| "\"#{c}\"" }.join(", ")} FROM #{klass.table_name}",
        )
        .each do |row|
          if row["user_id"]
            old_user_id = row["user_id"].to_i

            next if skip_if_merged && @merged_user_ids.include?(old_user_id)

            if is_a_user_model
              next if old_user_id < 1
              next if user_id_from_imported_id(old_user_id).nil?
              # We import non primary emails as long as they are not already in use as primary
              if klass.table_name == "user_emails" && row["primary"] == "f" &&
                   UserEmail.where(email: row["email"]).first
                next
              end
            end

            if old_user_id >= 1
              row["user_id"] = user_id_from_imported_id(old_user_id)
              if is_a_user_model && row["user_id"].nil?
                raise "user_id nil for user id '#{old_user_id}'"
              end
              next if row["user_id"].nil? # associated record for a deleted user
            end
          end

          row["upload_id"] = upload_id_from_imported_id(row["upload_id"]) if row["upload_id"]

          row["group_id"] = group_id_from_imported_id(row["group_id"]) if row["group_id"]
          row["category_id"] = category_id_from_imported_id(row["category_id"]) if row[
            "category_id"
          ]
          if row["category_id"].nil? &&
               (
                 klass.table_name == "category_custom_fields" ||
                   klass.table_name == "category_featured_topics"
               )
            next
          end

          if row["topic_id"] && klass != Category
            row["topic_id"] = topic_id_from_imported_id(row["topic_id"])
            next if row["topic_id"].nil?
          end
          if row["post_id"]
            row["post_id"] = post_id_from_imported_id(row["post_id"])
            next if row["post_id"].nil?
          end
          row["tag_id"] = tag_id_from_imported_id(row["tag_id"]) if row["tag_id"]
          row["tag_group_id"] = tag_group_id_from_imported_id(row["tag_group_id"]) if row[
            "tag_group_id"
          ]
          row["deleted_by_id"] = user_id_from_imported_id(row["deleted_by_id"]) if row[
            "deleted_by_id"
          ]
          row["badge_id"] = badge_id_from_imported_id(row["badge_id"]) if row["badge_id"]
          row["granted_title_badge_id"] = badge_id_from_imported_id(
            row["granted_title_badge_id"],
          ) if row["granted_title_badge_id"]

          if row["bookmarkable_id"]
            row["bookmarkable_id"] = post_id_from_imported_id(row["bookmarkable_id"]) if row[
              "bookmarkable_type"
            ] == "Post"
            row["bookmarkable_id"] = topic_id_from_imported_id(row["bookmarkable_id"]) if row[
              "bookmarkable_type"
            ] == "Topic"
          end

          row["poll_id"] = poll_id_from_imported_id(row["poll_id"]) if row["poll_id"]

          row["poll_option_id"] = poll_option_id_from_imported_id(row["poll_option_id"]) if row[
            "poll_option_id"
          ]

          row["raw"] = process_raw(row["raw"], row["topic_id"]) if row["raw"] && row["topic_id"]

          row["flair_group_id"] = group_id_from_imported_id(row["flair_group_id"]) if row[
            "flair_group_id"
          ]

          row["muted_user_id"] = user_id_from_imported_id(row["muted_user_id"]) if row[
            "muted_user_id"
          ]

          if row["user_profile_id"]
            row["user_profile_id"] = user_id_from_imported_id(row["user_id"])
            next unless row["user_profile_id"]
          end

          row["ignored_user_id"] = user_id_from_imported_id(row["ignored_user_id"]) if row[
            "ignored_user_id"
          ]

          if klass.table_name == "user_uploads"
            next if row["upload_id"].nil?
          end

          row["flair_upload_id"] = upload_id_from_imported_id(row["flair_upload_id"]) if row[
            "flair_upload_id"
          ]

          row["uploaded_logo_id"] = upload_id_from_imported_id(row["uploaded_logo_id"]) if row[
            "uploaded_logo_id"
          ]

          row["uploaded_logo_dark_id"] = upload_id_from_imported_id(
            row["uploaded_logo_dark_id"],
          ) if row["uploaded_logo_dark_id"]

          row["uploaded_background_id"] = upload_id_from_imported_id(
            row["uploaded_background_id"],
          ) if row["uploaded_background_id"]

          row["profile_background_upload_id"] = upload_id_from_imported_id(
            row["profile_background_upload_id"],
          ) if row["profile_background_upload_id"]

          row["card_background_upload_id"] = upload_id_from_imported_id(
            row["card_background_upload_id"],
          ) if row["card_background_upload_id"]

          if klass.table_name == "upload_references"
            next unless row["upload_id"]
            next unless remap_upload_reference_target(row)
          end

          old_id = row["id"].to_i
          if old_id && last_id
            row["id"] = (last_id += 1)
            imported_ids << old_id if has_custom_fields
            mapping[old_id] = row["id"] if mapping
          end

          if skip_processing
            @raw_connection.put_copy_data(row.values)
          else
            process_method_name = "process_#{klass.name.underscore}"

            processed =
              (
                if respond_to?(process_method_name)
                  send(process_method_name, ActiveSupport::HashWithIndifferentAccess.new(row))
                else
                  row
                end
              )

            @raw_connection.put_copy_data columns.map { |c| processed[c] } if processed
          end
        end
    end

    @sequences[klass.sequence_name] = last_id + 1 if last_id

    if has_custom_fields
      id_mapping_method_name = "#{klass.name.downcase}_id_from_imported_id"
      return unless respond_to?(id_mapping_method_name)
      create_custom_fields(klass.name.downcase, "id", imported_ids) do |imported_id|
        { record_id: send(id_mapping_method_name, imported_id), value: imported_id }
      end
    end
  end

  def copy_model_user_search_data(
    klass,
    skip_if_merged: false,
    is_a_user_model: false,
    skip_processing: false,
    mapping: nil,
    select_sql: nil
  )
    puts "copying #{klass.table_name}..."

    columns = klass.columns.map(&:name)
    has_custom_fields = CUSTOM_FIELDS.include?(klass.name.downcase)
    imported_ids = []
    last_id = columns.include?("id") ? (klass.unscoped.maximum(:id) || 1) : nil
    sql = "COPY #{klass.table_name} (#{columns.map { |c| "\"#{c}\"" }.join(", ")}) FROM STDIN"
    @raw_connection.copy_data(sql, @encoder) do
      source_raw_connection
        .exec(
          select_sql ||
            "SELECT #{columns.map { |c| "\"#{c}\"" }.join(", ")} FROM #{klass.table_name}",
        )
        .each do |row|
          if row["user_id"]
            old_user_id = row["user_id"].to_i

            next if skip_if_merged && @merged_user_ids.include?(old_user_id)

            if is_a_user_model
              next if old_user_id < 1
              next if user_id_from_imported_id(old_user_id).nil?
            end

            if old_user_id >= 1
              row["user_id"] = user_id_from_imported_id(old_user_id)
              if is_a_user_model && row["user_id"].nil?
                raise "user_id nil for user id '#{old_user_id}'"
              end
              next if row["user_id"].nil? # associated record for a deleted user
            end
          end

          exists = UserSearchData.where(user_id: row["user_id"])
          @raw_connection.put_copy_data(row.values) if exists.nil? || exists.empty?
        end
    end

    @sequences[klass.sequence_name] = last_id + 1 if last_id

    if has_custom_fields
      id_mapping_method_name = "#{klass.name.downcase}_id_from_imported_id"
      return unless respond_to?(id_mapping_method_name)
      create_custom_fields(klass.name.downcase, "id", imported_ids) do |imported_id|
        { record_id: send(id_mapping_method_name, imported_id), value: imported_id }
      end
    end
  end

  def process_topic(topic)
    return nil if topic["category_id"].nil? && topic["archetype"] != Archetype.private_message
    topic["last_post_user_id"] = user_id_from_imported_id(topic["last_post_user_id"]) || -1
    topic["featured_user1_id"] = user_id_from_imported_id(topic["featured_user1_id"]) || -1
    topic["featured_user2_id"] = user_id_from_imported_id(topic["featured_user2_id"]) || -1
    topic["featured_user3_id"] = user_id_from_imported_id(topic["featured_user3_id"]) || -1
    topic["featured_user4_id"] = user_id_from_imported_id(topic["featured_user4_id"]) || -1
    topic
  end

  def process_post(post)
    post["last_editor_id"] = user_id_from_imported_id(post["last_editor_id"]) || -1
    post["reply_to_user_id"] = user_id_from_imported_id(post["reply_to_user_id"]) || -1
    post["locked_by_id"] = user_id_from_imported_id(post["locked_by_id"]) || -1
    post["image_upload_id"] = upload_id_from_imported_id(post["image_upload_id"])
    post
  end

  def process_post_reply(post_reply)
    post_reply["reply_post_id"] = post_id_from_imported_id(
      post_reply["reply_post_id"],
    ) if post_reply["reply_post_id"]
    post_reply
  end

  def process_quoted_post(quoted_post)
    quoted_post["quoted_post_id"] = post_id_from_imported_id(
      quoted_post["quoted_post_id"],
    ) if quoted_post["quoted_post_id"]
    return nil if quoted_post["quoted_post_id"].nil?
    quoted_post
  end

  def process_post_action(post_action)
    return nil if post_action["post_id"].blank?
    post_action["related_post_id"] = post_id_from_imported_id(post_action["related_post_id"])
    post_action["deferred_by_id"] = user_id_from_imported_id(post_action["deferred_by_id"])
    post_action["agreed_by_id"] = user_id_from_imported_id(post_action["agreed_by_id"])
    post_action["disagreed_by_id"] = user_id_from_imported_id(post_action["disagreed_by_id"])
    post_action
  end

  def process_user_action(user_action)
    user_action["target_topic_id"] = topic_id_from_imported_id(
      user_action["target_topic_id"],
    ) if user_action["target_topic_id"]
    user_action["target_post_id"] = post_id_from_imported_id(
      user_action["target_post_id"],
    ) if user_action["target_post_id"]
    user_action["target_user_id"] = user_id_from_imported_id(
      user_action["target_user_id"],
    ) if user_action["target_user_id"]
    user_action["acting_user_id"] = user_id_from_imported_id(
      user_action["acting_user_id"],
    ) if user_action["acting_user_id"]
    user_action["queued_post_id"] = post_id_from_imported_id(
      user_action["queued_post_id"],
    ) if user_action["queued_post_id"]
    user_action
  end

  def process_tag_group(tag_group)
    tag_group["parent_tag_id"] = tag_id_from_imported_id(tag_group["parent_tag_id"]) if tag_group[
      "parent_tag_id"
    ]
    tag_group
  end

  def process_category_group(category_group)
    return nil if category_group["category_id"].nil? || category_group["group_id"].nil?
    category_group
  end

  def process_group_user(group_user)
    if @auto_group_ids.include?(group_user["group_id"].to_i) &&
         @merged_user_ids.include?(group_user["user_id"].to_i)
      return nil
    end
    return nil if group_user["user_id"].to_i < 1
    group_user
  end

  def process_group_history(group_history)
    group_history["acting_user_id"] = user_id_from_imported_id(
      group_history["acting_user_id"],
    ) if group_history["acting_user_id"]
    group_history["target_user_id"] = user_id_from_imported_id(
      group_history["target_user_id"],
    ) if group_history["target_user_id"]
    group_history
  end

  def process_group_archived_message(gam)
    return nil if gam["topic_id"].blank? || gam["group_id"].blank?
    gam
  end

  def process_topic_link(topic_link)
    topic_link["link_topic_id"] = topic_id_from_imported_id(
      topic_link["link_topic_id"],
    ) if topic_link["link_topic_id"]
    topic_link["link_post_id"] = post_id_from_imported_id(topic_link["link_post_id"]) if topic_link[
      "link_post_id"
    ]
    topic_link
  end

  def process_user_avatar(user_avatar)
    user_avatar["custom_upload_id"] = upload_id_from_imported_id(
      user_avatar["custom_upload_id"],
    ) if user_avatar["custom_upload_id"]
    user_avatar["gravatar_upload_id"] = upload_id_from_imported_id(
      user_avatar["gravatar_upload_id"],
    ) if user_avatar["gravatar_upload_id"]
    return nil if user_avatar["custom_upload_id"].blank? && user_avatar["gravatar_upload_id"].blank?
    user_avatar
  end

  def process_user_history(user_history)
    return nil if user_history["group_id"].blank?
    user_history["acting_user_id"] = user_id_from_imported_id(
      user_history["acting_user_id"],
    ) if user_history["acting_user_id"]
    user_history["target_user_id"] = user_id_from_imported_id(
      user_history["target_user_id"],
    ) if user_history["target_user_id"]
    user_history
  end

  def process_user_warning(user_warning)
    user_warning["created_by_id"] = user_id_from_imported_id(
      user_warning["created_by_id"],
    ) if user_warning["created_by_id"]
    return nil if user_warning["created_by_id"].blank?
    user_warning
  end

  def process_notification(notification)
    notification["post_action_id"] = post_action_id_from_imported_id(
      notification["post_action_id"],
    ) if notification["post_action_id"]
    notification
  end

  def process_oauth2_user_info(r)
    return nil if Oauth2UserInfo.where(uid: r["uid"], provider: r["provider"]).exists?
    r
  end

  def process_user_associated_account(r)
    if UserAssociatedAccount.where(provider_uid: r["uid"], provider_name: r["provider"]).exists?
      return nil
    end
    r
  end

  def process_single_sign_on_record(r)
    return nil if SingleSignOnRecord.where(external_id: r["external_id"]).exists?
    r
  end

  def process_user_badge(user_badge)
    user_badge["granted_by_id"] = user_id_from_imported_id(
      user_badge["granted_by_id"],
    ) if user_badge["granted_by_id"]
    user_badge["notification_id"] = notification_id_from_imported_id(
      user_badge["notification_id"],
    ) if user_badge["notification_id"]
    if UserBadge.where(user_id: user_badge["user_id"], badge_id: user_badge["badge_id"]).exists?
      return nil
    end
    user_badge
  end

  def process_email_change_request(ecr)
    ecr["old_email_token_id"] = email_token_id_from_imported_id(ecr["old_email_token_id"]) if ecr[
      "old_email_token_id"
    ]
    ecr["new_email_token_id"] = email_token_id_from_imported_id(ecr["new_email_token_id"]) if ecr[
      "new_email_token_id"
    ]
    ecr["requested_by_user_id"] = user_id_from_imported_id(ecr["requested_by_user_id"]) if ecr[
      "requested_by_user_id"
    ]
    ecr
  end

  def process_tag_user(x)
    return nil if TagUser.where(tag_id: x["tag_id"], user_id: x["user_id"]).exists?
    x
  end

  def process_topic_tag(x)
    return nil if TopicTag.where(topic_id: x["topic_id"], tag_id: x["tag_id"]).exists?
    x
  end

  def process_category_tag(x)
    return nil if CategoryTag.where(category_id: x["category_id"], tag_id: x["tag_id"]).exists?
    x
  end

  def process_category_tag_stat(x)
    return nil if CategoryTagStat.where(category_id: x["category_id"], tag_id: x["tag_id"]).exists?
    x
  end

  def process_tag_group_membership(x)
    if TagGroupMembership.where(tag_group_id: x["tag_group_id"], tag_id: x["tag_id"]).exists?
      return nil
    end
    x
  end

  def process_category_tag_group(x)
    if CategoryTagGroup.where(
         category_id: x["category_id"],
         tag_group_id: x["tag_group_id"],
       ).exists?
      return nil
    end
    x
  end

  def process_category_required_tag_group(x)
    if CategoryRequiredTagGroup.where(
         category_id: x["category_id"],
         tag_group_id: x["tag_group_id"],
       ).exists?
      return nil
    end
    x
  end

  def process_tag_group_permission(x)
    if TagGroupPermission.where(tag_group_id: x["tag_group_id"], group_id: x["group_id"]).exists?
      return nil
    end
    x
  end

  def process_muted_user(x)
    return nil if MutedUser.where(user_id: x["user_id"], muted_user_id: x["muted_user_id"]).exists?
    x
  end

  def process_ignored_user(x)
    if IgnoredUser.where(user_id: x["user_id"], ignored_user_id: x["ignored_user_id"]).exists?
      return nil
    end
    x
  end

  def process_user_upload(x)
    return nil if UserUpload.where(upload_id: x["upload_id"], user_id: x["user_id"]).exists?
    x
  end

  def process_category_user(x)
    return nil if CategoryUser.where(category_id: x["category_id"], user_id: x["user_id"]).exists?
    x
  end

  def process_upload_reference(x)
    if UploadReference.where(
         upload_id: x["upload_id"],
         target_type: x["target_type"],
         target_id: x["target_id"],
       ).exists?
      return nil
    end
    x
  end

  def process_category_search_data(x)
    return nil if CategorySearchData.where(category_id: x["category_id"]).exists?
    x
  end

  def process_raw(raw, topic_id)
    new_raw = raw.dup

    quote_pattern = /\[quote=\"(.*)?topic:(\d+)(.*)?\"\]/im
    if new_raw.match?(quote_pattern)
      new_raw.gsub!(/(\[quote=\"(.*)?topic:)(\d+)((.*)?\"\])/i) { "#{$1}#{topic_id}#{$4}" }
    end

    new_url = Discourse.base_url
    topic_url_pattern = %r{#{@source_base_url}/t/([^/]*[^\d/][^/]*)/(\d+)/?(\d+)?}im
    if new_raw.match?(topic_url_pattern)
      new_raw.gsub!(topic_url_pattern) do
        import_topic_id = topic_id_from_imported_id($2)
        "#{new_url}\/t\/#{$1}\/#{import_topic_id}\/#{$3}"
      end
    end

    new_raw
  end

  def user_id_from_imported_id(id)
    return id if id.to_i < 1
    super(id)
  end

  def group_id_from_imported_id(id)
    return id if @auto_group_ids.include?(id&.to_i)
    super(id)
  end

  def tag_id_from_imported_id(id)
    @tags[id.to_s]
  end

  def tag_group_id_from_imported_id(id)
    @tag_groups[id.to_s]
  end

  def upload_id_from_imported_id(id)
    @uploads[id.to_s]
  end

  def post_action_id_from_imported_id(id)
    @post_actions[id.to_s]
  end

  def badge_id_from_imported_id(id)
    @badges[id.to_s]
  end

  def notification_id_from_imported_id(id)
    @notifications[id.to_s]
  end

  def email_token_id_from_imported_id(id)
    @email_tokens[id.to_s]
  end

  def poll_id_from_imported_id(id)
    @polls[id.to_s]
  end

  def poll_option_id_from_imported_id(id)
    @poll_options[id.to_s]
  end

  def avatar_id_from_imported_id(id)
    @avatars[id.to_s]
  end

  def fix_primary_keys
    # Later stages insert through ActiveRecord after a table's counter was
    # captured, so a sequence must never be set below the table's current ids.
    # Seeded system rows have negative ids and are ignored.
    @sequences.each do |sequence_name, val|
      table_name = sequence_table_name(sequence_name)
      @raw_connection.exec(<<~SQL)
        SELECT setval('#{sequence_name}', GREATEST(
          #{val.to_i},
          COALESCE((SELECT MAX(id) FROM #{table_name} WHERE id > 0), 0) + 1
        ))
      SQL
    end
  end

  def sequence_table_name(sequence_name)
    @raw_connection.exec_params(<<~SQL, [sequence_name]).getvalue(0, 0)
      SELECT refobjid::regclass::text
      FROM pg_depend
      WHERE classid = 'pg_class'::regclass
        AND objid = $1::regclass
        AND refclassid = 'pg_class'::regclass
        AND deptype IN ('a', 'i')
    SQL
  end

  def fix_user_columns
    puts "updating foreign keys in the users table..."

    User
      .where("id >= ?", @first_new_user_id)
      .find_each do |u|
        arr = []
        sql = "UPDATE users SET".dup

        if new_approved_by_id = user_id_from_imported_id(u.approved_by_id)
          arr << " approved_by_id = #{new_approved_by_id}"
        end
        if new_primary_group_id = group_id_from_imported_id(u.primary_group_id)
          arr << " primary_group_id = #{new_primary_group_id}"
        end
        if new_notification_id = notification_id_from_imported_id(u.seen_notification_id)
          arr << " seen_notification_id = #{new_notification_id}"
        end

        next if arr.empty?

        sql << arr.join(", ")
        sql << " WHERE id = #{u.id}"

        @raw_connection.exec(sql)
      end
  end

  def fix_polls
    puts "Adding polls custom fields..."

    @polls.each_value do |new_poll_id|
      post_id = Poll.find_by_id(new_poll_id)&.post_id
      # Polls on deleted posts are valid, see Poll's post association.
      post = Post.with_deleted.find_by_id(post_id) if post_id
      next if post.nil?

      post.custom_fields[DiscoursePoll::HAS_POLLS] = true
      post.save_custom_fields(true)
    end
  end

  def fix_featured_topic
    puts "Updating featured topic ids..."
    # Fixups write only the remapped column because rows are copied verbatim
    # from the source site and may not pass current validations.
    UserProfile
      .where("user_id >= ?", @first_new_user_id)
      .where.not(featured_topic_id: nil)
      .find_each do |profile|
        profile.update_columns(
          featured_topic_id: topic_id_from_imported_id(profile.featured_topic_id),
        )
      end
  end

  def fix_user_upload
    puts "Updating avatar ids..."

    # Users have a column "uploaded_avatar_id" which needs to be mapped now.
    User
      .where("id >= ?", @first_new_user_id)
      .where.not(uploaded_avatar_id: nil)
      .find_each do |u|
        new_avatar_id = upload_id_from_imported_id(u.uploaded_avatar_id)
        u.update_columns(uploaded_avatar_id: new_avatar_id) if new_avatar_id
      end
  end

  private

  # Returns nil when the target cannot be remapped and the reference should be skipped.
  def remap_upload_reference_target(row)
    # TO-DO: add other target types
    row["target_id"] = case row["target_type"]
    when "UserProfile", "User"
      user_id_from_imported_id(row["target_id"])
    when "UserAvatar"
      avatar_id_from_imported_id(row["target_id"])
    when "Post"
      post_id_from_imported_id(row["target_id"])
    end

    row if row["target_id"]
  end
end

BulkImport::DiscourseMerger.new.start if $PROGRAM_NAME == __FILE__

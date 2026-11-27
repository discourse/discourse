# frozen_string_literal: true

# Loaded by the runner after the destination has been selected and guarded.
require_relative "support"
require_relative "matched_activity"
require_relative "content_transfer"
require_relative "group_mapping"
require_relative "topic_link_rows"
require_relative "../base"
require_relative "verifier"
require "fileutils"
require "csv"

module BulkImport::DiscourseMerge
  class Merger < BulkImport::Base
    attr_reader :category_keys, :source_raw_connection, :media_urls

    CUSTOM_FIELDS = %w[category group post topic user].freeze

    REQUIRED_MODELS = %w[
      Badge
      BadgeGrouping
      Bookmark
      Category
      CategoryCustomField
      CategoryFeaturedTopic
      CategoryFormTemplate
      CategoryGroup
      CategoryPostingReviewGroup
      CategoryRequiredTagGroup
      CategorySetting
      CategoryTag
      CategoryTagGroup
      CategoryUser
      DoNotDisturbTiming
      EmailChangeRequest
      EmailToken
      GivenDailyLike
      Group
      GroupArchivedMessage
      GroupCategoryNotificationDefault
      GroupCustomField
      GroupHistory
      GroupMention
      GroupTagNotificationDefault
      GroupUser
      IgnoredUser
      IncomingEmail
      MutedUser
      Notification
      OptimizedImage
      Oauth2UserInfo
      Permalink
      Poll
      PollOption
      PollVote
      Post
      PostAction
      PostCustomField
      PostDetail
      PostReply
      PostRevision
      PostStat
      PostTiming
      QuotedPost
      SingleSignOnRecord
      SiteSetting
      Tag
      TagGroup
      TagGroupMembership
      TagGroupPermission
      TagUser
      Topic
      TopicAllowedGroup
      TopicAllowedUser
      TopicCustomField
      TopicEmbed
      TopicLink
      TopicSearchData
      TopicTag
      TopicTimer
      TopicUser
      TopicViewItem
      UnsubscribeKey
      Upload
      UploadReference
      User
      UserAction
      UserArchivedMessage
      UserAssociatedAccount
      UserAvatar
      UserBadge
      UserCustomField
      UserEmail
      UserHistory
      UserOption
      UserProfile
      UserProfileView
      UserSecondFactor
      UserStat
      UserUpload
      UserVisit
      UserWarning
    ].freeze

    LEGACY_FIELDS = %w[
      ai_agent_id
      discourse_ai_bot_user_pref_id
      is_ai_bot_pm
      yearly_review
      has_chat_enabled
    ].freeze
    ASSOCIATION_KEYS = {
      "tag_users" => %w[user_id tag_id],
      "topic_tags" => %w[topic_id tag_id],
      "category_tags" => %w[category_id tag_id],
      "tag_group_memberships" => %w[tag_group_id tag_id],
      "category_tag_groups" => %w[category_id tag_group_id],
      "category_required_tag_groups" => %w[category_id tag_group_id],
      "tag_group_permissions" => %w[tag_group_id group_id],
      "group_tag_notification_defaults" => %w[group_id tag_id],
      "group_category_notification_defaults" => %w[group_id category_id],
      "muted_users" => %w[user_id muted_user_id],
      "ignored_users" => %w[user_id ignored_user_id],
      "user_uploads" => %w[upload_id user_id],
      "category_users" => %w[category_id user_id],
      "upload_references" => %w[upload_id target_type target_id],
      "topic_allowed_users" => %w[topic_id user_id],
      "topic_users" => %w[topic_id user_id],
    }.freeze

    PROCESS_TABLES = %w[
      bookmarks
      notifications
      post_revisions
      topic_timers
      user_profiles
      category_custom_fields
      post_custom_fields
      topic_custom_fields
      user_custom_fields
    ].freeze

    def initialize(
      plan:,
      run_dir:,
      configuration:,
      source_connection:,
      destination_connection:,
      progress: Progress.new
    )
      @plan, @run_dir, @configuration = plan, Pathname.new(run_dir), configuration
      state = JSON.parse(@run_dir.join("state.json").read)
      raise Error, "Execution was not checkpointed" unless state["mutation_started"]
      @raw_connection = destination_connection
      @progress = progress
      @source_raw_connection = source_connection
      @encoder = PG::TextEncoder::CopyRow.new
      @source_base_url = @configuration.data.fetch("source_url").delete_suffix("/")
      @uploads_path = plan.data.dig("upload_policy", "source_upload_root")
      @auto_group_ids = Group::AUTO_GROUPS.values
      @merged_user_ids, @sequences = Set.new, {}
      %i[
        tags
        tag_groups
        uploads
        post_actions
        post_revisions
        notifications
        badge_groupings
        badges
        email_tokens
        polls
        poll_options
        avatars
        optimized_images
        topic_timers
        solved_topics
        topic_answers
        shared_issues
      ].each { |name| instance_variable_set(:"@#{name}", {}) }
      @excluded_groups = GroupMapping.excluded(plan.data.fetch("groups", []))
      @selection = Selection.new(plan)
      @category_keys, @username_changes, @group_changes = {}, {}, {}
      @generated_topics, @generated_posts, @audit = [], [], []
      @original_authors = {}
      @revision_author_fallbacks = []
      @historical_bot_ids = []
      @source_categories =
        source_raw_connection
          .exec("SELECT * FROM categories ORDER BY id")
          .index_by { |r| r.fetch("id").to_i }
    end

    def start
      run
    end

    def run
      @progress.start("importer initialization")
      I18n.locale = ENV.fetch("LOCALE", SiteSettings::DefaultsProvider::DEFAULT_LOCALE).to_sym
      ActiveSupport::Inflector.transliterate("test")
      load_imported_ids
      load_indexes
      execute
      checkpoint("copied")
      @progress.start("custom fields, links, and category statistics")
      fix_primary_keys
      execute_after
      checkpoint("complete")
    end

    def load_imported_ids
      @groups, @users, @categories, @topics, @posts = {}, {}, {}, {}, {}
      destination_groups = Group.where(automatic: true).pluck(:name, :id).to_h
      @auto_group_ids =
        source_raw_connection
          .exec("SELECT id, name FROM groups WHERE automatic")
          .map do |group|
            id = group.fetch("id").to_i
            target = destination_groups[group.fetch("name")]
            @groups[id] = target if target
            id
          end
      [-1, -2].each do |id|
        source =
          source_raw_connection.exec_params("SELECT username FROM users WHERE id=$1", [id]).first
        unless source && User.find(id).username == source.fetch("username")
          raise Error, "Canonical system account differs: #{id}"
        end
        @users[id] = id
      end
    end

    def load_indexes
      @last_user_id = last_id(User)
      @last_topic_id = last_id(Topic)
      @last_category_id = last_id(Category)
      @first_new_group_id = last_id(Group) + 1
    end

    def user_id_from_imported_id(id)
      @users[id.to_i] unless id.nil?
    end

    def create_custom_fields(table, name, rows)
      sql =
        "COPY #{table}_custom_fields (#{table}_id, name, value, created_at, updated_at) FROM STDIN"
      @raw_connection.copy_data(sql, @encoder) do
        rows.each do |row|
          field = yield(row)
          now = Time.now.utc.iso8601(6)
          if field
            @raw_connection.put_copy_data(
              [
                field[:record_id],
                "#{@configuration.namespace}_import_#{name}",
                field[:value],
                now,
                now,
              ],
            )
          end
        end
      end
    end

    def copy_users
      rows =
        source_raw_connection.exec(
          "SELECT u.*, e.email AS merge_email FROM users u JOIN user_emails e ON e.user_id=u.id AND e.primary WHERE u.id>0 ORDER BY u.id",
        ).to_a
      source_raw_connection
        .exec("SELECT * FROM users WHERE id < -2 ORDER BY id")
        .each do |row|
          @historical_bot_ids << row.fetch("id").to_i
          row[
            "merge_email"
          ] = "#{@configuration.namespace}-bot-#{row.fetch("id").to_i.abs}@migration.invalid"
          row.merge!(
            "admin" => "f",
            "moderator" => "f",
            "active" => "f",
            "approved" => "f",
            "staged" => "t",
            "trust_level" => "0",
            "password_hash" => nil,
            "salt" => nil,
          )
          rows << row
        end
      existing =
        UserEmail
          .joins(:user)
          .where(email: rows.map { |r| r.fetch("merge_email") })
          .pluck(:email, :user_id, "users.username")
          .to_h { |email, id, name| [email, [id, name]] }
      @account_outcomes = {}
      columns, taken, imported = User.column_names, Set.new, []
      preserve_staff_roles = @plan.preserve_staff_roles?
      @raw_connection.copy_data(copy_sql(User), @encoder) do
        rows.each do |row|
          original = row.fetch("id").to_i
          email = row.delete("merge_email")
          if original < -2 && existing[email]
            raise Error, "Historical bot placeholder email already exists"
          end
          if existing[email]
            id, final = existing.fetch(email)
            name = row.fetch("username")
            @users[original] = id
            @username_changes[name] = final unless name == final
            @account_outcomes[original] = {
              "source_username" => name,
              "final_username" => final,
              "reason" => "email_match",
            }
            @merged_user_ids << original
            next
          end
          row.merge!("admin" => "f", "moderator" => "f") unless preserve_staff_roles
          base = row.fetch("username")
          candidate, suffix = base, 0
          while taken.include?(candidate.downcase) ||
                  User.unscoped.where(username_lower: candidate.downcase).exists?
            suffix += 1
            tail = "_#{suffix}"
            candidate = base[0, UsernameValidator::MAX_CHARS - tail.length] + tail
          end
          taken << candidate.downcase
          row["username"], row["username_lower"] = candidate, candidate.downcase
          row["id"] = (@last_user_id += 1)
          @users[original] = row["id"]
          if base != candidate
            @username_changes[base] = candidate
            if original.positive?
              @account_outcomes[original] = {
                "source_username" => base,
                "final_username" => candidate,
                "reason" => "username_collision",
              }
            end
          end
          @raw_connection.put_copy_data(columns.map { |c| row[c] })
          imported << original
        end
      end
      @sequences[User.sequence_name] = @last_user_id + 1
      create_custom_fields("user", "id", imported) do |id|
        { record_id: @users.fetch(id), value: id }
      end
      copy_model(
        EmailToken,
        skip_if_merged: true,
        is_a_user_model: true,
        skip_processing: true,
        mapping: @email_tokens,
      )
      copy_model(UserEmail, skip_if_merged: true, is_a_user_model: true, skip_processing: true)
      @historical_bot_ids.each do |original|
        id = last_id(UserEmail) + 1
        UserEmail.insert_all!(
          [
            {
              id: id,
              user_id: @users.fetch(original),
              email: "#{@configuration.namespace}-bot-#{original.abs}@migration.invalid",
              primary: true,
              created_at: Time.now.utc,
              updated_at: Time.now.utc,
            },
          ],
        )
        @sequences[UserEmail.sequence_name] = id + 1
      end
      checkpoint("users")
    end

    def copy_user_stuff
      copy_model(UserProfile, skip_if_merged: true, is_a_user_model: true, skip_processing: true)

      # Push subscriptions belong to browser sessions, which are not merged.
      [UserStat, UserOption, GivenDailyLike, UserSecondFactor, DoNotDisturbTiming].each do |c|
        copy_model(c, skip_if_merged: true, is_a_user_model: true, skip_processing: true)
      end

      visit_query = "SELECT #{quoted_columns(UserVisit)} FROM user_visits WHERE user_id > 0"
      if @merged_user_ids.any?
        visit_query << " AND user_id NOT IN (#{@plan.sql_ids(@merged_user_ids)})"
      end
      copy_model(UserVisit, select_sql: visit_query, is_a_user_model: true, skip_processing: true)

      [MutedUser, IgnoredUser].each { |c| copy_model(c, is_a_user_model: true) }

      [
        UserAssociatedAccount,
        Oauth2UserInfo,
        SingleSignOnRecord,
        EmailChangeRequest,
        UserProfileView,
      ].each { |c| copy_model(c, skip_if_merged: true, is_a_user_model: true) }

      copy_model(UserAvatar, skip_if_merged: true, is_a_user_model: true, mapping: @avatars)
      @historical_bot_ids.each do |original|
        [UserProfile, UserStat, UserOption, UserAvatar].each do |klass|
          row =
            source_raw_connection.exec_params(
              "SELECT * FROM #{klass.table_name} WHERE user_id=$1",
              [original],
            ).first
          raise Error, "Historical bot lacks #{klass.table_name}" unless row
          attrs =
            row
              .slice(*klass.column_names)
              .to_h { |k, v| [k, klass.attribute_types.fetch(k).deserialize(v)] }
              .except("id")
          attrs["user_id"] = @users.fetch(original)
          %w[
            profile_background_upload_id
            card_background_upload_id
            custom_upload_id
            gravatar_upload_id
          ].each { |k| attrs[k] = @uploads[attrs[k]] if attrs[k] }
          attrs["flair_group_id"] = nil if attrs.key?("flair_group_id")
          attrs["granted_title_badge_id"] = nil if attrs.key?("granted_title_badge_id")
          if klass == UserAvatar
            attrs["id"] = last_id(UserAvatar) + 1
            @avatars[row.fetch("id").to_i] = attrs.fetch("id")
            @sequences[UserAvatar.sequence_name] = attrs.fetch("id") + 1
          end
          klass.insert_all!([attrs])
        end
        @audit << {
          event: "historical_bot_isolated",
          source_user_id: original,
          destination_user_id: @users.fetch(original),
        }
      end
    end

    def plan_upload_root
      @plan.data.fetch("upload_policy").fetch("destination_upload_root")
    end

    def copy_uploads
      if @configuration.preuploaded?
        return(
          PreuploadedMedia.open(@plan.data, @run_dir) do |media|
            @prepared_media = media
            copy_remote_uploads
          ensure
            @prepared_media = nil
          end
        )
      end
      return copy_remote_uploads if @configuration.preserve_remote?
      existing = Upload.unscoped.where.not(sha1: nil).pluck(:sha1, :id).to_h
      bad_hashes = @plan.data.dig("upload_policy", "source_hash_discrepancy_ids").to_set
      last = last_id(Upload)
      root = Pathname.new(@uploads_path).realpath
      destination_root = Pathname.new(plan_upload_root)
      FileUtils.mkdir_p(destination_root)
      unless destination_root.realpath == destination_root
        raise Error, "Unexpected upload destination"
      end
      @raw_connection.copy_data(copy_sql(Upload), @encoder) do
        source_raw_connection
          .exec("SELECT * FROM uploads ORDER BY id")
          .each do |row|
            original = row.fetch("id").to_i
            if original < 0
              builtin = Upload.unscoped.find_by(id: original)
              unless builtin && builtin.url == row["url"]
                raise Error, "Built-in upload differs: #{original}"
              end
              @uploads[original] = original
              next
            end
            relative = row.fetch("url").delete_prefix("/uploads/default/")
            raise Error, "Unexpected upload path" unless row["url"].start_with?("/uploads/default/")
            source_file = Artifacts.upload_path(root, relative)
            if existing[row["sha1"]]
              if bad_hashes.include?(original)
                raise Error, "Anomalous upload hash collides: #{original}"
              end
              reused = Upload.unscoped.find(existing.fetch(row["sha1"]))
              unless reused.url.start_with?("/uploads/default/")
                raise Error, "Reused upload must be local"
              end
              destination_file =
                Artifacts.upload_path(
                  destination_root,
                  reused.url.delete_prefix("/uploads/default/"),
                )
              unless Digest::SHA256.file(source_file) == Digest::SHA256.file(destination_file)
                raise Error, "Reused upload bytes differ: #{original}"
              end
              remember_media_url(row.fetch("url"), reused.url) if row["url"] != reused.url
              @uploads[original] = reused.id
              next
            end
            destination = Artifacts.upload_path(destination_root, relative, existing: false)
            if destination.exist?
              unless Digest::SHA256.file(source_file) == Digest::SHA256.file(destination)
                raise Error, "Local file collision: #{original}"
              end
            else
              FileUtils.mkdir_p(destination.dirname)
              FileUtils.cp(source_file, destination)
            end
            remap_author!(row, "uploads")
            row["id"] = (last += 1)
            @uploads[original] = row["id"]
            @raw_connection.put_copy_data(Upload.column_names.map { |c| row[c] })
          end
      end
      @sequences[Upload.sequence_name] = last + 1
      checkpoint("uploads")
    end

    def remember_media_url(source, destination)
      @media_urls ||= {}
      @media_urls[source] = destination
      @media_urls[Media.remote_url(source, @source_base_url)] = destination
    end

    def copy_remote_uploads
      reuse =
        @plan
          .data
          .fetch("upload_policy")
          .fetch("reuse")
          .to_h { |pair| pair.values_at("source_upload_id", "destination_upload_id") }
      existing =
        Upload.unscoped.where(id: reuse.values).or(Upload.unscoped.where("id < 0")).index_by(&:id)
      last = last_id(Upload)
      @raw_connection.copy_data(copy_sql(Upload), @encoder) do
        SourceRows.each(source_raw_connection, "SELECT * FROM uploads ORDER BY id") do |row|
          original = row.fetch("id").to_i
          source_url = row.fetch("url")
          reused =
            if original < 0
              existing[original]
            elsif reuse.key?(original)
              existing.fetch(reuse.fetch(original)) do
                raise Error, "Reviewed destination upload is missing for #{original}"
              end
            end
          prepared =
            @prepared_media&.source_result("uploads", original, reused&.id) if original.positive?
          if reused
            if original < 0
              raise Error, "Built-in upload differs: #{original}" unless reused.url == source_url
            else
              Media.validate_reuse!(row, reused.attributes)
            end
            @uploads[original] = reused.id
            destination_url =
              Media.remote_url(reused.url, @configuration.data.fetch("destination_url"))
          else
            raise Error, "Missing built-in upload: #{original}" if original < 0
            if prepared
              row.merge!(@prepared_media.attributes("uploads", prepared))
              if (post_id = row.delete("access_control_post_id"))
                (@upload_control_posts ||= {})[last + 1] = post_id.to_i
              end
            else
              row["url"] = Media.remote_url(source_url, @source_base_url)
            end
            remap_author!(row, "uploads")
            row["id"] = (last += 1)
            @uploads[original] = row["id"]
            @raw_connection.put_copy_data(Upload.column_names.map { |column| row[column] })
            destination_url = row.fetch("url")
          end
          if @prepared_media && original.positive?
            @prepared_media.map_urls(
              @media_urls ||= {},
              "source",
              source_url,
              prepared,
              destination_url,
            )
          else
            remember_media_url(source_url, destination_url)
          end
        end
      end
      @sequences[Upload.sequence_name] = last + 1
      copy_remote_optimized_images
      checkpoint("uploads")
    end

    def copy_remote_optimized_images
      keys = %w[upload_id width height extension]
      existing =
        OptimizedImage
          .unscoped
          .pluck(*keys, :id, :url)
          .to_h { |values| [values.take(keys.size).map(&:to_s), values.last(2)] }
      last = last_id(OptimizedImage)
      @raw_connection.copy_data(copy_sql(OptimizedImage), @encoder) do
        SourceRows.each(
          source_raw_connection,
          "SELECT * FROM optimized_images ORDER BY id",
        ) do |row|
          original = row.fetch("id").to_i
          source_url = row.fetch("url")
          row["upload_id"] = @uploads.fetch(row.fetch("upload_id").to_i)
          key = keys.map { |column| row[column].to_s }
          reused = existing[key]
          prepared = @prepared_media&.source_result("optimized_images", original, reused&.first)
          if reused
            id, url = reused
            @optimized_images[original] = id
            destination_url = Media.remote_url(url, @configuration.data.fetch("destination_url"))
          else
            if prepared
              row.merge!(@prepared_media.attributes("optimized_images", prepared))
            else
              row["url"] = Media.remote_url(source_url, @source_base_url)
            end
            row["id"] = (last += 1)
            @optimized_images[original] = row["id"]
            @raw_connection.put_copy_data(OptimizedImage.column_names.map { |column| row[column] })
            destination_url = row.fetch("url")
          end
          if @prepared_media && original.positive?
            @prepared_media.map_urls(
              @media_urls ||= {},
              "source",
              source_url,
              prepared,
              destination_url,
            )
          else
            remember_media_url(source_url, destination_url)
          end
        end
      end
      @sequences[OptimizedImage.sequence_name] = last + 1
    end

    def copy_groups
      instructions = @plan.data.fetch("groups")
      @reused_source_group_ids =
        instructions
          .select { |group| group.fetch("action") == "reuse" }
          .map { |group| group.fetch("source_group_id") }
      reused_ids = instructions.filter_map { |group| group["destination_group_id"] }.uniq
      instructions.each do |group|
        @groups[group.fetch("source_group_id")] = group.fetch(
          "destination_group_id",
        ) if group.fetch("action") == "reuse"
      end
      copies = instructions.select { |group| group.fetch("action") == "copy" }
      clauses =
        copies.map do |group|
          "WHEN #{Integer(group.fetch("source_group_id"))} THEN #{@raw_connection.escape_literal(group.fetch("name"))}"
        end
      columns =
        Group.column_names.map do |column|
          if column == "name" && clauses.any?
            "CASE id #{clauses.join(" ")} ELSE name END AS name"
          elsif %w[smtp_ssl_mode imap_uid_validity imap_last_uid].include?(column)
            "0 AS #{PG::Connection.quote_ident(column)}"
          elsif column == "imap_mailbox_name"
            "'' AS imap_mailbox_name"
          elsif %w[smtp_enabled imap_enabled].include?(column)
            "false AS #{PG::Connection.quote_ident(column)}"
          elsif (
                Group::SMTP_SETTING_ATTRIBUTES +
                  %w[
                    incoming_email
                    imap_server
                    imap_port
                    imap_ssl
                    imap_last_error
                    imap_old_emails
                    imap_new_emails
                    email_username
                    email_password
                    smtp_updated_at
                    smtp_updated_by_id
                    imap_updated_at
                    imap_updated_by_id
                  ]
              ).include?(column)
            "NULL AS #{PG::Connection.quote_ident(column)}"
          else
            PG::Connection.quote_ident(column)
          end
        end
      copy_model(
        Group,
        mapping: @groups,
        skip_processing: true,
        select_sql:
          "SELECT #{columns.join(",")} FROM groups WHERE id IN (#{@plan.sql_ids(copies.map { |group| group.fetch("source_group_id") })}) ORDER BY id",
      )
      @group_memberships =
        GroupMemberships.new(
          GroupUser.where(group_id: reused_ids, user_id: @users.values).pluck(:group_id, :user_id),
          reused_ids,
        )
      copy_model(GroupUser)
      assign_destination_automatic_groups
      names = Group.where(id: @groups.values).pluck(:id, :name).to_h
      source_raw_connection
        .exec("SELECT id, name FROM groups")
        .each do |row|
          mapped = names[group_id_from_imported_id(row["id"])]
          @group_changes[row["name"]] = mapped if mapped && mapped != row["name"]
        end
      @references = nil
      checkpoint("groups")
    end

    def assign_destination_automatic_groups
      last = last_id(GroupUser)
      new_users =
        @users.filter_map do |original, id|
          id if original > 0 && !@merged_user_ids.include?(original)
        end
      new_users.each_slice(1000) do |ids|
        memberships =
          User
            .select(:id, :trust_level, :admin, :moderator)
            .find(ids)
            .flat_map do |user|
              groups = Group.desired_trust_level_groups(user.trust_level)
              groups << Group::AUTO_GROUPS[:admins] if user.admin?
              groups << Group::AUTO_GROUPS[:moderators] if user.moderator?
              groups << Group::AUTO_GROUPS[:staff] if user.staff?
              groups.map do |group_id|
                { id: (last += 1), group_id: group_id, user_id: user.id, owner: false }
              end
            end
        GroupUser.insert_all!(memberships)
      end
      @sequences[GroupUser.sequence_name] = last + 1
    end

    def process_group_user(row)
      return @group_memberships.add(row) if @group_memberships
      row if row["user_id"].to_i > 0
    end

    def copy_tags
      return unless @plan.data.fetch("policy").fetch("import_tags", true)
      last, targets, created = last_id(Tag), {}, Set.new
      @raw_connection.copy_data(copy_sql(Tag), @encoder) do
        source_raw_connection
          .exec("SELECT #{quoted_columns(Tag)} FROM tags ORDER BY id")
          .each do |row|
            original = row.fetch("id").to_i
            existing = Tag.where_name(row.fetch("name")).first
            if existing
              @tags[original] = existing.id
              next
            end
            targets[original] = row["target_tag_id"]&.to_i
            row["target_tag_id"] = nil
            row["id"] = (last += 1)
            @tags[original] = row["id"]
            created << original
            @raw_connection.put_copy_data(Tag.column_names.map { |c| row[c] })
          end
      end
      created.each do |original|
        next unless targets[original]
        target = @tags.fetch(targets.fetch(original))
        raise Error, "Self-referencing source tag" if target == @tags.fetch(original)
        Tag.where(id: @tags.fetch(original)).update_all(target_tag_id: target)
      end
      @sequences[Tag.sequence_name] = last + 1
      [TagUser, TopicTag, CategoryTag].each { |klass| copy_model(klass) }
      copy_model(
        TagGroup,
        mapping: @tag_groups,
        select_sql: merge_same_named_rows(TagGroup, @tag_groups, max_name_length: 100),
      )
      [
        TagGroupMembership,
        CategoryTagGroup,
        CategoryRequiredTagGroup,
        TagGroupPermission,
      ].each { |klass| copy_model(klass) }
    end

    # Called by core after users/files/groups. Build the final tree directly;
    # dissolved categories become aliases, not temporary live categories.
    def copy_categories_with_no_parent
      @plan
        .data
        .fetch("categories")
        .sort_by { |r| r.fetch("path").length }
        .each do |item|
          if item["operation"] == "preserve_existing"
            @category_keys[item.fetch("key")] = item.fetch("destination_category_id")
            next
          end
          path = item.fetch("path")
          parent =
            (
              if path.length > 1
                @category_keys.fetch(
                  @plan
                    .data
                    .fetch("categories")
                    .find { |r| r["path"] == path[0...-1] }
                    .fetch("key"),
                )
              else
                nil
              end
            )
          source_id = item["source_category_id"]
          attrs =
            if source_id
              @source_categories
                .fetch(source_id)
                .slice(*Category.column_names)
                .to_h { |k, v| [k, Category.attribute_types.fetch(k).deserialize(v)] }
            else
              Category.new.attributes
            end
          attrs.merge!(
            "id" => (@last_category_id += 1),
            "name" => path.last,
            "name_lower" => path.last.downcase,
            "parent_category_id" => parent,
            "topic_id" => nil,
            "user_id" => (source_id ? user_id_from_imported_id(attrs["user_id"]) : -1) || -1,
            "read_restricted" => item.fetch("access") != "public",
          )
          base, n = Slug.for(path.last), 0
          attrs["slug"] = base
          while Category.unscoped.where(parent_category_id: parent, slug: attrs["slug"]).exists?
            n += 1
            attrs["slug"] = "#{base}-#{@configuration.namespace}-#{n}"
          end
          %w[uploaded_logo_id uploaded_logo_dark_id uploaded_background_id].each do |k|
            attrs[k] = @uploads[attrs[k].to_i] if attrs[k]
          end
          attrs["reviewable_by_group_id"] = group_id_from_imported_id(
            attrs["reviewable_by_group_id"],
          ) if attrs["reviewable_by_group_id"]
          attrs["created_at"] ||= Time.now.utc
          attrs["updated_at"] ||= Time.now.utc
          Category.insert_all!([attrs])
          id = attrs.fetch("id")
          setting_source =
            source_id &&
              source_raw_connection.exec_params(
                "SELECT * FROM category_settings WHERE category_id=$1",
                [source_id],
              ).first
          setting =
            (
              if setting_source
                setting_source
                  .slice(*CategorySetting.column_names)
                  .to_h { |k, v| [k, CategorySetting.attribute_types.fetch(k).deserialize(v)] }
              else
                CategorySetting.new.attributes
              end
            )
          setting = setting.except("id").merge("category_id" => id)
          setting["created_at"] ||= Time.now.utc
          setting["updated_at"] ||= Time.now.utc
          CategorySetting.insert_all!([setting])
          @category_keys[item.fetch("key")] = id
          @categories[source_id] = id if source_id
          CategoryGroup.insert_all!(
            GroupMapping
              .grants(item.fetch("grants"), @groups)
              .map { |grant| grant.merge(category_id: id) },
          )
        end
      @plan
        .data
        .fetch("source_category_actions")
        .each do |r|
          @categories[r.fetch("source_category_id")] = r["destination_key"] &&
            @category_keys.fetch(r.fetch("destination_key"))
        end
      @sequences[Category.sequence_name] = @last_category_id + 1
      checkpoint("categories")
    end

    def copy_topics
      last = last_id(Topic)
      @raw_connection.copy_data(copy_sql(Topic), @encoder) do
        sql =
          "SELECT #{quoted_columns(Topic)} FROM topics WHERE id IN (#{@selection.included_topics}) ORDER BY id"
        SourceRows.each(source_raw_connection, sql) do |row|
          original = row.fetch("id").to_i
          instruction = @plan.topic(original)
          remap_author!(row, "topics")
          row["category_id"] = instruction["destination_key"] &&
            @category_keys.fetch(instruction["destination_key"])
          row["deleted_by_id"] = user_id_from_imported_id(row["deleted_by_id"]) if row[
            "deleted_by_id"
          ]
          %w[image_upload_id og_image_upload_id].each do |key|
            row[key] = @uploads[row[key].to_i] if row[key]
          end
          row = process_topic(row)
          raise Error, "Topic unexpectedly skipped" unless row
          row["id"] = (last += 1)
          @topics[original] = row["id"]
          @raw_connection.put_copy_data(Topic.column_names.map { |c| row[c] })
        end
      end
      @sequences[Topic.sequence_name] = last + 1
      [
        TopicAllowedGroup,
        TopicAllowedUser,
        TopicEmbed,
        TopicSearchData,
        TopicTimer,
        TopicUser,
        TopicViewItem,
      ].each do |klass|
        klass == TopicTimer ? copy_model(klass, mapping: @topic_timers) : copy_model(klass)
      end
      checkpoint("topics")
    end

    # Several source members may match different emails of the same destination member.
    # Collapse their activity on a copied topic before remapping the user foreign key.
    def selected_member_activity(klass, sql)
      groups =
        @merged_user_ids
          .group_by { |original| @users.fetch(original) }
          .values
          .select { |ids| ids.size > 1 }
      return sql if groups.empty?
      aliases = groups.flat_map { |ids| ids.map { |id| "(#{Integer(id)}, #{Integer(ids.min)})" } }
      aggregate =
        if klass == PostTiming
          "SELECT topic_id, post_number, canonical AS user_id, LEAST(SUM(msecs), 2147483647)::int AS msecs
           FROM selected JOIN aliases USING (user_id) GROUP BY topic_id, post_number, canonical"
        else
          "SELECT ip_address, MIN(viewed_at) AS viewed_at, topic_id, canonical AS user_id
           FROM selected JOIN aliases USING (user_id) GROUP BY ip_address, topic_id, canonical"
        end
      columns = quoted_columns(klass)
      <<~SQL
        WITH selected AS (#{sql}), aliases(user_id, canonical) AS (VALUES #{aliases.join(",")})
        SELECT #{columns} FROM selected WHERE user_id IS NULL OR user_id NOT IN (SELECT user_id FROM aliases)
        UNION ALL SELECT #{columns} FROM (#{aggregate}) combined
      SQL
    end

    def copy_model(klass, **options)
      return copy_profile_views if klass == UserProfileView
      columns = klass.column_names
      if !@plan.data.fetch("policy").fetch("import_tags", true) &&
           (columns.include?("tag_id") || columns.include?("tag_group_id"))
        return
      end
      sql = options[:select_sql] || "SELECT #{quoted_columns(klass)} FROM #{klass.table_name}"
      if %w[
           group_custom_fields
           group_category_notification_defaults
           group_tag_notification_defaults
         ].include?(klass.table_name) && @reused_source_group_ids&.any?
        sql =
          "SELECT preserved.* FROM (#{sql}) preserved WHERE group_id NOT IN (#{@plan.sql_ids(@reused_source_group_ids)})"
      end
      options[:select_sql] = @selection.sql(
        klass.table_name,
        columns,
        sql,
        auto_groups: @auto_group_ids,
      )
      if @plan.data["merge_member_activity"] && [PostTiming, TopicViewItem].include?(klass)
        options[:select_sql] = selected_member_activity(klass, options[:select_sql])
      end
      options[:skip_if_merged] = false if klass == GroupUser
      options[:skip_processing] = false if ASSOCIATION_KEYS.key?(klass.table_name) ||
        PROCESS_TABLES.include?(klass.table_name) || columns.include?("user_id")
      original_count =
        if options[:select_sql] != sql
          source_raw_connection.exec("SELECT count(*) FROM (#{sql}) original").getvalue(0, 0).to_i
        end
      if klass == TopicLink
        options[
          :select_sql
        ] = "SELECT * FROM (#{options[:select_sql]}) selected ORDER BY topic_id, post_id, id"
      elsif ASSOCIATION_KEYS.key?(klass.table_name)
        options[:select_sql] = "SELECT * FROM (#{options[:select_sql]}) selected ORDER BY id"
      end
      selected, written = copy_model_rows(klass, **options)
      @audit << {
        table: klass.table_name,
        selected: selected,
        written: written,
        filtered: (original_count || selected) - selected,
      }
    end

    def merger_processor_for(klass)
      name = "process_#{klass.name.underscore}"
      processor = method(name) if respond_to?(name)
      processor = nil if processor && BulkImport::Base.ancestors.include?(processor.owner)
      associations = association_filter(klass)
      lambda do |row|
        if row["user_id"] && row["user_id"].to_i < -2
          row["user_id"] = @users.fetch(row["user_id"].to_i)
        end
        row = processor.call(row) if processor
        row if row && (!associations || associations.accept?(row))
      end
    end

    def association_filter(klass)
      keys = ASSOCIATION_KEYS[klass.table_name]
      if keys
        mappings = {
          "category_id" => @categories,
          "group_id" => @groups,
          "tag_group_id" => @tag_groups,
          "topic_id" => @topics,
          "upload_id" => @uploads,
          "user_id" => @users,
        }
        existing = klass.unscoped.where(keys.first => mappings.fetch(keys.first).values.uniq)
        return(
          AssociationFilter.new(
            [keys],
            existing: existing.pluck(*keys),
            permission: klass.table_name == "tag_group_permissions",
          )
        )
      end
      return if klass.column_names.exclude?("group_id") || klass == GroupUser
      indexes =
        klass
          .connection
          .indexes(klass.table_name)
          .filter_map do |index|
            if index.unique && index.columns.is_a?(Array) && index.columns.include?("group_id")
              index.columns
            end
          end
      AssociationFilter.new(indexes) if indexes.any?
    end

    def copy_profile_views
      count = 0
      last = last_id(UserProfileView)
      @raw_connection.copy_data(copy_sql(UserProfileView), @encoder) do
        sql = "SELECT #{quoted_columns(UserProfileView)} FROM user_profile_views"
        SourceRows.each(source_raw_connection, sql) do |row|
          source_profile = row.fetch("user_profile_id").to_i
          next unless @users[source_profile]
          if row["user_id"]
            source_user = row.fetch("user_id").to_i
            next if @merged_user_ids.include?(source_user) || !@users[source_user]
            row["user_id"] = @users.fetch(source_user)
          else
            # Matched destination profiles retain their own anonymous analytics;
            # avoid colliding with the same visitor/day already recorded there.
            next if @merged_user_ids.include?(source_profile)
          end
          row["user_profile_id"] = @users.fetch(source_profile)
          row["id"] = (last += 1)
          @raw_connection.put_copy_data(UserProfileView.column_names.map { |c| row[c] })
          count += 1
        end
      end
      @sequences[UserProfileView.sequence_name] = last + 1
      @audit << { table: "user_profile_views", selected: count }
    end

    def references
      @references ||=
        References.from_plan(
          @plan,
          { topics: @topics, categories: @categories, uploads: @uploads, users: @users },
          source_connection: source_raw_connection,
          usernames: @username_changes,
          group_names: @group_changes,
          media_urls: @media_urls || {},
        )
    end

    def process_raw(raw, _topic_id)
      references.rewrite(raw)
    end

    def process_post(row)
      %w[last_editor_id reply_to_user_id].each do |column|
        row[column] = user_id_from_imported_id(row[column]) || -1
      end
      row["locked_by_id"] = References.post_locker(row["locked_by_id"], @users)
      row["image_upload_id"] = upload_id_from_imported_id(row["image_upload_id"])
      row
    end

    def process_bookmark(row)
      row if row["bookmarkable_id"]
    end

    def process_topic_timer(row)
      row["timerable_id"] = @topics[row["timerable_id"].to_i]
      row if row["timerable_id"]
    end

    def process_category_form_template(row)
      row["form_template_id"] = @plan
        .data
        .fetch("form_templates")
        .fetch(row.fetch("form_template_id"))
      row
    end

    def process_category_featured_topic(row)
      row if Topic.with_deleted.where(id: row["topic_id"], category_id: row["category_id"]).exists?
    end

    def maps
      {
        users: @users,
        groups: @groups,
        categories: @categories,
        topics: @topics,
        posts: @posts,
        uploads: @uploads,
        optimized_images: @optimized_images,
        topic_timers: @topic_timers,
        solved_topics: @solved_topics,
        topic_answers: @topic_answers,
        shared_issues: @shared_issues,
        post_actions: @post_actions,
        post_revisions: @post_revisions,
      }
    end

    def process_notification(row)
      row["post_action_id"] = post_action_id_from_imported_id(row["post_action_id"]) if row[
        "post_action_id"
      ]
      row["data"] = JSON.generate(references.metadata(JSON.parse(row.fetch("data")), maps))
      row
    rescue Error
      @audit << { event: "notification_with_unmapped_reference_skipped" }
      nil
    end

    def process_post_revision(row)
      missing = Set.new
      if row["modifications"]
        coder = PostRevision.type_for_attribute("modifications")
        row["modifications"] = coder.serialize(
          references.revision(
            coder.deserialize(row["modifications"]),
            maps,
            excluded_groups: @excluded_groups,
            namespace: @configuration.namespace,
            source_revision_id: row.fetch("source_revision_id"),
            missing_users: missing,
          ),
        )
      end
      if (editor = row["original_editor_id"])
        missing << editor
      end
      if missing.any?
        @revision_author_fallbacks << {
          revision_id: row["id"],
          post_id: row["post_id"],
          original_user_ids: missing.to_a.sort,
          original_editor_id: editor,
        }.compact
      end
      row
    end

    def process_user_profile(row)
      # Repair once in execute_after, when topic and group maps are complete.
      # Reapplying username rewrites can follow a second source user's rename.
      row
    end

    def process_user_associated_account(row)
      row["avatar_upload_id"] = @uploads[row["avatar_upload_id"].to_i] if row["avatar_upload_id"]
      unless UserAssociatedAccount.where(
               provider_uid: row["provider_uid"],
               provider_name: row["provider_name"],
             ).exists?
        row
      end
    end

    def copy_solved
      models = {
        "DiscourseSolved::SolvedTopic" => @solved_topics,
        "DiscourseSolved::TopicAnswer" => @topic_answers,
        "DiscourseSolved::SharedIssue" => @shared_issues,
      }
      models.each do |name, mapping|
        klass = name.safe_constantize
        next unless klass
        last = last_id(klass)
        @raw_connection.copy_data(copy_sql(klass), @encoder) do
          source_raw_connection
            .exec("SELECT #{quoted_columns(klass)} FROM #{klass.table_name} ORDER BY id")
            .each do |row|
              original = row.fetch("id").to_i
              next if row["topic_id"] && !@topics.key?(row["topic_id"].to_i)
              next if row["solved_topic_id"] && !@solved_topics.key?(row["solved_topic_id"].to_i)
              remap_solved_row!(row)
              row["id"] = (last += 1)
              mapping[original] = row["id"]
              @raw_connection.put_copy_data(klass.column_names.map { |column| row[column] })
            end
        end
        @sequences[klass.sequence_name] = last + 1
      end
    end

    def remap_solved_row!(row)
      {
        "topic_id" => @topics,
        "topic_timer_id" => @topic_timers,
        "solved_topic_id" => @solved_topics,
        "answer_post_id" => @posts,
        "accepter_user_id" => @users,
        "user_id" => @users,
      }.each do |column, mapping|
        next unless row[column]
        row[column] = mapping.fetch(row[column].to_i) do
          raise Error, "Unmapped solved reference #{column}=#{row[column]}"
        end
      end
      row
    end

    def fix_user_columns
      User
        .where("id >= ?", @first_new_user_id)
        .find_each { |user| user.update_columns(remapped_user_columns(user)) }
    end

    def remapped_user_columns(user)
      primary_group = group_id_from_imported_id(user.primary_group_id)
      flair_group = group_id_from_imported_id(user.flair_group_id)
      unless @plan.preserve_staff_roles?
        staff_groups = Group::AUTO_GROUPS.values_at(*Group::STAFF_GROUPS)
        primary_group = nil if staff_groups.include?(primary_group)
        flair_group = nil if staff_groups.include?(flair_group)
      end
      {
        approved_by_id:
          user.approved_by_id && (user_id_from_imported_id(user.approved_by_id) || -1),
        primary_group_id: primary_group,
        flair_group_id: flair_group,
        seen_notification_id: @notifications[user.seen_notification_id] || 0,
      }
    end

    def fix_user_upload
      User
        .where("id >= ?", @first_new_user_id)
        .where.not(uploaded_avatar_id: nil)
        .find_each do |user|
          user.update_columns(uploaded_avatar_id: @uploads[user.uploaded_avatar_id])
        end
    end

    def fix_category_descriptions
      @source_categories.each do |original, row|
        next if @plan.retained_category_ids.exclude?(original)
        topic = @topics[row["topic_id"].to_i]
        Category.where(id: @categories.fetch(original)).update_all(topic_id: topic) if topic
      end
    end

    def process_custom_field(row)
      if LEGACY_FIELDS.include?(row["name"])
        @audit << { event: "legacy_metadata_namespaced", name: row["name"] }
        row["name"] = "#{@configuration.namespace}_original_#{row["name"]}"
      elsif row["name"] == "action_code_who"
        row["value"] = @username_changes[row["value"]] || row["value"]
      elsif row["name"] == "deleted_public_actions"
        original = JSON.parse(row["value"])
        repaired = Array(original).filter_map { |id| @post_actions[id.to_i] }
        if repaired.size != Array(original).size
          row["name"] = "#{@configuration.namespace}_original_deleted_public_actions"
        else
          row["value"] = original.is_a?(Array) ? JSON.generate(repaired) : repaired.fetch(0).to_s
        end
      elsif row["value"]&.start_with?("{", "[")
        value = JSON.parse(row["value"])
        if GroupMapping.metadata_references?(value, @excluded_groups) ||
             GroupMapping.metadata_references?({ row["name"] => value }, @excluded_groups)
          row["name"] = "#{@configuration.namespace}_original_#{row["name"]}"
          @audit << { event: "excluded_group_metadata_preserved", name: row["name"] }
        else
          row["value"] = JSON.generate(references.metadata(value, maps))
        end
      elsif GroupMapping.metadata_references?({ row["name"] => row["value"] }, @excluded_groups)
        row["name"] = "#{@configuration.namespace}_original_#{row["name"]}"
        @audit << { event: "excluded_group_metadata_preserved", name: row["name"] }
      end
      row
    end
    alias process_post_custom_field process_custom_field
    alias process_topic_custom_field process_custom_field
    alias process_user_custom_field process_custom_field
    alias process_category_custom_field process_custom_field

    def execute_after
      profile_filter = " AND name !~ '^user_field_[0-9]+$'" if @plan.data.key?("content")
      copy_model(
        PostCustomField,
        select_sql:
          "SELECT #{quoted_columns(PostCustomField)} FROM post_custom_fields WHERE name NOT LIKE 'import_%' AND name NOT LIKE '#{@configuration.namespace}_import_%'",
      )
      copy_model(
        TopicCustomField,
        select_sql:
          "SELECT #{quoted_columns(TopicCustomField)} FROM topic_custom_fields WHERE name NOT LIKE 'import_%' AND name NOT LIKE '#{@configuration.namespace}_import_%'",
      )
      copy_model(
        UserCustomField,
        skip_if_merged: true,
        is_a_user_model: true,
        select_sql:
          "SELECT #{quoted_columns(UserCustomField)} FROM user_custom_fields WHERE name NOT LIKE 'import_%'#{profile_filter}",
      )
      copy_model(
        GroupCustomField,
        select_sql:
          "SELECT #{quoted_columns(GroupCustomField)} FROM group_custom_fields WHERE name NOT LIKE 'import_%'",
      )
      # COPY assigns IDs explicitly; synchronize before subsequent inserts
      # allocate custom-field IDs for preservation notes.
      fix_primary_keys
      if (decisions = @plan.data["content"])
        @content_ids = {}
        ContentTransfer.new(
          source_raw_connection,
          @raw_connection,
          maps.merge(tags: @tags),
          @category_keys,
          references,
          @content_ids,
        ).copy(decisions)
        originals =
          decisions
            .fetch("custom_emojis", [])
            .filter_map { |row| row.fetch("id") if row["action"] == "copied" }
        @copied_emoji_ids = @content_ids.fetch("custom_emojis", {}).slice(*originals)
      end
      copy_upload_references
      if @content_ids
        decisions
          .fetch("published_pages", [])
          .each do |r|
            next unless r["retained_topic"]
            @audit << {
              table: "published_pages",
              source_id: r.fetch("id"),
              reason: r.fetch("reason"),
              destination_topic_url:
                "#{@configuration.data.fetch("destination_url")}/t/#{@topics.fetch(r.fetch("retained_topic"))}",
            }
          end
        ids = @copied_emoji_ids.values
        UploadReference.connection.reset_pk_sequence!(UploadReference.table_name) if ids.any?
        CustomEmoji
          .where(id: ids)
          .in_batches do |batch|
            UploadReference.insert_all(
              batch
                .pluck(:id, :upload_id)
                .map do |id, upload|
                  { target_type: "CustomEmoji", target_id: id, upload_id: upload }
                end,
            )
          end
      end
      UserProfile
        .where(user_id: @users.values.select { |id| id >= @first_new_user_id })
        .find_each do |profile|
          profile.update_columns(
            bio_raw: references.rewrite(profile.bio_raw),
            bio_cooked: references.rewrite(profile.bio_cooked, cooked: true),
          )
        end
      source_raw_connection
        .exec(
          "SELECT user_id,granted_title_badge_id FROM user_profiles WHERE granted_title_badge_id IS NOT NULL",
        )
        .each do |row|
          original = row.fetch("user_id").to_i
          next if @merged_user_ids.include?(original) || !@users[original]
          UserProfile.where(user_id: @users.fetch(original)).update_all(
            granted_title_badge_id: @badges[row.fetch("granted_title_badge_id").to_i],
          )
        end
      Group
        .where(id: @groups.values.select { |id| id >= @first_new_group_id })
        .find_each do |group|
          group.update_columns(
            bio_raw: references.rewrite(group.bio_raw),
            bio_cooked: references.rewrite(group.bio_cooked, cooked: true),
          )
        end
      @original_authors
        .fetch("topics", [])
        .each do |row|
          TopicCustomField.insert_all!(
            [
              {
                topic_id: @topics.fetch(row.fetch("id")),
                name: "#{@configuration.namespace}_original_user_id",
                value: row.fetch("user_id").to_s,
                created_at: Time.now.utc,
                updated_at: Time.now.utc,
              },
            ],
          )
        end
      @revision_author_fallbacks.each do |record|
        PostCustomField.insert_all!(
          [
            {
              post_id: record.fetch(:post_id),
              name: "#{@configuration.namespace}_original_revision_authors",
              value: JSON.generate(record),
              created_at: Time.now.utc,
              updated_at: Time.now.utc,
            },
          ],
        )
      end
      restore_definitions
      generate_missing_definitions
      apply_tags
      build_permalinks
      if @plan.data["merge_member_activity"]
        matched = @users.slice(*@merged_user_ids.select(&:positive?))
        @matched_summaries = MatchedActivity.new(source_raw_connection, matched, @audit).apply!
      end
      refresh_scoped_statistics
      checkpoint("customized")
      @progress.start("post and search indexing")
      SearchIndexer.with_indexing { recook_imported_posts }
      fix_primary_keys
    end

    def self.definition_topic_attributes(category_id, name, now: Time.now.utc)
      Topic
        .new(
          user_id: -1,
          last_post_user_id: -1,
          category_id: category_id,
          title: "About the #{name} category",
          created_at: now,
          updated_at: now,
          bumped_at: now,
          last_posted_at: now,
          posts_count: 1,
          highest_post_number: 1,
        )
        .attributes
        .slice(*Topic.column_names)
        .except("id")
    end

    def self.definition_post_attributes(topic_id, name, now: Time.now.utc)
      Post
        .new(
          user_id: -1,
          topic_id: topic_id,
          post_number: 1,
          raw: "Discussion about #{name}.",
          cooked: "<p>Discussion about #{ERB::Util.html_escape(name)}.</p>",
          created_at: now,
          updated_at: now,
          last_version_at: now,
        )
        .attributes
        .slice(*Post.column_names)
        .except("id")
    end

    def generate_missing_definitions
      incoming_category_ids.each do |id|
        category = Category.find(id)
        next if category.topic_id
        topic_id =
          Topic
            .insert_all!(
              [self.class.definition_topic_attributes(id, category.name)],
              returning: %w[id],
            )
            .rows
            .first
            .first
        post_id =
          Post
            .insert_all!(
              [self.class.definition_post_attributes(topic_id, category.name)],
              returning: %w[id],
            )
            .rows
            .first
            .first
        category.update_columns(topic_id: topic_id)
        @generated_topics << topic_id
        @generated_posts << post_id
      end
    end

    def restore_definitions
      @plan.categories.each_value do |item|
        next unless item["source_category_id"]
        original = @source_categories.fetch(item.fetch("source_category_id"))["topic_id"]
        mapped = original && @topics[original.to_i]
        if mapped
          Category.where(id: @category_keys.fetch(item.fetch("key"))).update_all(topic_id: mapped)
        end
      end
    end

    def apply_tags
      @plan
        .data
        .fetch("topics")
        .each do |instruction|
          instruction
            .fetch("add_tags")
            .each do |name|
              tag = Tag.where_name(name).first
              unless tag
                id =
                  Tag
                    .insert_all!(
                      [
                        {
                          name: name,
                          slug: name,
                          created_at: Time.now.utc,
                          updated_at: Time.now.utc,
                        },
                      ],
                      returning: %w[id],
                    )
                    .rows
                    .first
                    .first
                tag = Tag.find(id)
              end
              TopicTag.insert_all(
                [
                  {
                    topic_id: @topics.fetch(instruction.fetch("source_topic_id")),
                    tag_id: tag.id,
                    created_at: Time.now.utc,
                    updated_at: Time.now.utc,
                  },
                ],
                unique_by: %i[topic_id tag_id],
              )
            end
        end
    end

    def build_permalinks
      topic_redirects = {}
      source_raw_connection
        .exec("SELECT id, slug, archetype, deleted_at FROM topics ORDER BY id")
        .each do |row|
          original = row["id"].to_i
          next unless row["archetype"] == "regular" && @topics[original] && row["deleted_at"].nil?
          Permalink.insert_all!(
            [
              {
                url: "#{@configuration.namespace}/t/#{original}",
                topic_id: @topics.fetch(original),
              },
            ],
          )
          topic_redirects[original] = @topics.fetch(original)
        end
      @plan
        .data
        .fetch("source_category_actions")
        .each do |row|
          if row["operation"] == "dissolve_after_routing"
            tag = Tag.find_by!(name: row.fetch("tag"))
            Permalink.insert_all!(
              [
                {
                  url: "#{@configuration.namespace}/c/#{row.fetch("source_category_id")}",
                  tag_id: tag.id,
                },
              ],
            )
          elsif row["destination_key"]
            Permalink.insert_all!(
              [
                {
                  url: "#{@configuration.namespace}/c/#{row.fetch("source_category_id")}",
                  category_id: @category_keys.fetch(row.fetch("destination_key")),
                },
              ],
            )
          end
        end
      Artifacts.write(
        @run_dir.join("redirects.json"),
        JSON.pretty_generate(
          source_host: @plan.data.dig("policy", "source_host"),
          destination_host: @plan.data.dig("policy", "destination_host"),
          topics: topic_redirects,
          routing:
            "On the old host, extract the original topic ID before any destination lookup, map it using topics, preserve /post-number suffix and fragment. Do not redirect old /t paths unchanged.",
        ),
      )
    end

    def incoming_category_ids
      @plan
        .data
        .fetch("categories")
        .reject { |r| r["operation"] == "preserve_existing" }
        .map { |r| @category_keys.fetch(r.fetch("key")) }
    end

    def refresh_scoped_statistics
      ids =
        (
          incoming_category_ids +
            @plan.topics.values.filter_map do |row|
              row["destination_key"] && @category_keys[row["destination_key"]]
            end
        ).uniq
      ids.each { |id| DB.exec(<<~SQL, id: id) }
          UPDATE categories SET
            topic_count=(SELECT count(*) FROM topics WHERE category_id=:id AND deleted_at IS NULL AND visible AND id NOT IN (SELECT topic_id FROM categories WHERE topic_id IS NOT NULL)),
            post_count=(SELECT coalesce(sum(posts_count),0) FROM topics WHERE category_id=:id AND deleted_at IS NULL AND visible AND id NOT IN (SELECT topic_id FROM categories WHERE topic_id IS NOT NULL))
          WHERE id=:id
        SQL
      affected = @users.values.select { |id| id > 0 }.uniq
      affected.each_slice(500) do |users|
        DB.exec(<<~SQL, users: users)
          UPDATE user_stats s SET
            post_count=(SELECT count(*) FROM posts p JOIN topics t ON t.id=p.topic_id WHERE p.user_id=s.user_id AND p.deleted_at IS NULL AND NOT p.hidden AND p.post_type=1 AND t.deleted_at IS NULL AND t.visible AND t.archetype='regular' AND t.id NOT IN (SELECT topic_id FROM categories WHERE topic_id IS NOT NULL)),
            topic_count=(SELECT count(*) FROM topics t WHERE t.user_id=s.user_id AND t.deleted_at IS NULL AND t.visible AND t.archetype='regular' AND t.id NOT IN (SELECT topic_id FROM categories WHERE topic_id IS NOT NULL))
          WHERE s.user_id IN (:users)
        SQL
        UserStat.recalculate_likes!(users)
      end
      tag_ids = TopicTag.where(topic_id: @topics.values).distinct.pluck(:tag_id)
      tag_ids.each { |id| DB.exec(<<~SQL, id: id) }
          UPDATE tags SET
            staff_topic_count=(SELECT count(*) FROM topic_tags x JOIN topics t ON t.id=x.topic_id WHERE x.tag_id=:id AND t.deleted_at IS NULL AND t.archetype='regular'),
            public_topic_count=(SELECT count(*) FROM topic_tags x JOIN topics t ON t.id=x.topic_id JOIN categories c ON c.id=t.category_id WHERE x.tag_id=:id AND t.deleted_at IS NULL AND t.visible AND t.archetype='regular' AND NOT c.read_restricted),
            pm_topic_count=(SELECT count(*) FROM topic_tags x JOIN topics t ON t.id=x.topic_id WHERE x.tag_id=:id AND t.deleted_at IS NULL AND t.archetype='private_message')
          WHERE id=:id
        SQL
      DB.exec("DELETE FROM category_tag_stats WHERE category_id IN (:ids)", ids: ids)
      DB.exec(<<~SQL, ids: ids)
        INSERT INTO category_tag_stats (category_id, tag_id, topic_count)
        SELECT t.category_id,x.tag_id,count(*) FROM topic_tags x JOIN topics t ON t.id=x.topic_id
        WHERE t.category_id IN (:ids) AND t.deleted_at IS NULL AND t.visible AND t.archetype='regular'
        GROUP BY t.category_id,x.tag_id
      SQL
      DB.exec(<<~SQL, ids: @groups.values.uniq)
        UPDATE groups g SET user_count=(SELECT count(*) FROM group_users gu WHERE gu.group_id=g.id)
        WHERE g.id IN (:ids)
      SQL
    end

    def recook_imported_posts
      # Index categories first because Core marks their post indexes for refresh.
      Category
        .where(id: incoming_category_ids)
        .find_each { |category| SearchIndexer.index(category, force: true) }
      scope = Post.with_deleted.where(id: @posts.values + @generated_posts)
      total = scope.count
      @progress&.say("Posts to index: #{total}")
      preserve_cooked =
        @configuration.preserve_remote? || @configuration.upload_mode == "preuploaded"
      scope
        .find_each
        .with_index(1) do |post, number|
          # Remote imports already rewrote the prepared source's HTML during COPY.
          # Keep its optimized image markup and rebuild the destination search index.
          if !preserve_cooked || post.cooked.blank?
            post.update_columns(
              cooked: post.cook(post.raw, topic_id: post.topic_id),
              baked_at: Time.now.utc,
              baked_version: Post::BAKED_VERSION,
            )
          end
          SearchIndexer.index(post, force: true)
          if number % 1000 == 0 || number == total
            puts "DISCOURSE_MERGE_INDEXED_POSTS: #{number}/#{total}"
            @progress&.say("Indexed #{number}/#{total} posts")
          end
        end
      puts "DISCOURSE_MERGE_INDEXING_USERS"
      @progress&.say("Indexing imported users")
      User
        .where(id: @users.values.select { |id| id >= @first_new_user_id })
        .find_each { |user| SearchIndexer.index(user, force: true) }
    end

    def remap_upload_reference_target(row)
      if row["target_type"] == "User" && @plan.data.key?("matched_avatars") &&
           @merged_user_ids.include?(row.fetch("target_id").to_i)
        return
      end
      mapping =
        case row["target_type"]
        when "Post"
          @posts
        when "Topic"
          @topics
        when "User", "UserProfile"
          @users
        when "CustomEmoji"
          @copied_emoji_ids
        when "PostLocalization"
          @content_ids&.fetch("post_localizations", {})
        when "UserAvatar"
          @avatars
        when "Group"
          @groups
        when "Category"
          @categories
        end
      row["target_id"] = mapping && mapping[row["target_id"].to_i]
      row if row["target_id"]
    end

    def checkpoint(stage)
      Artifacts.write(
        @run_dir.join("ledger.json"),
        JSON.pretty_generate(
          maps
            .transform_values { |map| map.transform_keys(&:to_s) }
            .merge(
              "category_keys" => @category_keys,
              "avatars" => @avatars,
              "generated_topics" => @generated_topics,
              "generated_posts" => @generated_posts,
              "original_authors" => @original_authors,
              "tags" => @tags,
              "polls" => @polls,
              "poll_options" => @poll_options,
              "notifications" => @notifications,
              "badges" => @badges,
              "badge_groupings" => @badge_groupings,
              "email_tokens" => @email_tokens,
              "tag_groups" => @tag_groups,
              "content_ids" => @content_ids || {},
              "stage" => stage,
              "media_urls" => @media_urls || {},
              "matched_summaries" => @matched_summaries || {},
              "username_changes" => @username_changes,
              "account_outcomes" => @account_outcomes,
              "group_changes" => @group_changes,
            ),
        ),
      )
      Artifacts.write(@run_dir.join("import-audit.json"), JSON.pretty_generate(@audit))
      puts "DISCOURSE_MERGE_STAGE: #{stage}"
      @progress.say("Saved #{stage} checkpoint")
    end

    def execute
      @first_new_user_id = @last_user_id + 1
      @first_new_topic_id = @last_topic_id + 1

      @progress.start("accounts and uploads")
      copy_users
      copy_uploads
      copy_user_stuff
      MatchedAvatars.adopt!(@plan.data.fetch("matched_avatars", []), @users, @uploads)
      @progress.start("groups and categories")
      copy_groups
      copy_categories_with_no_parent
      @progress.start("topics and posts")
      @progress.say("#{@plan.included_ids.size} selected source topics")
      copy_topics
      copy_posts
      @upload_control_posts&.each_slice(1000) do |batch|
        pairs = batch.map { |upload, post| "(#{Integer(upload)},#{Integer(@posts.fetch(post))})" }
        DB.exec(
          "UPDATE uploads u SET access_control_post_id=v.post_id FROM (VALUES #{pairs.join(",")}) v(id,post_id) WHERE u.id=v.id",
        )
      end
      @progress.say("Mapped #{@topics.size} topics and #{@posts.size} posts")
      copy_tags

      @progress.start("supporting records and references")
      copy_everything_else
      copy_badges
      copy_solved

      fix_user_columns
      fix_category_descriptions
      fix_polls
      fix_featured_topic
      fix_user_upload
    end

    def merge_same_named_rows(klass, _mapping, where: "TRUE", max_name_length:)
      existing_ids = klass.unscoped.pluck(:name, :id).to_h { |name, id| [name.downcase, id] }
      source_rows =
        source_raw_connection.exec("SELECT id, name FROM #{klass.table_name} WHERE #{where}").to_a
      taken_names = Set.new(existing_ids.keys) + source_rows.map { |row| row["name"].downcase }
      new_names = {}

      source_rows.each do |row|
        next unless existing_ids.key?(row["name"].downcase)

        new_names[row["id"].to_i] = free_name(row["name"], taken_names, max_name_length)
      end

      columns =
        klass.columns.map do |c|
          next "\"#{c.name}\"" if c.name != "name" || new_names.empty?
          whens =
            new_names.map do |id, name|
              "WHEN #{id} THEN #{ActiveRecord::Base.connection.quote(name)}"
            end
          "CASE id #{whens.join(" ")} ELSE name END AS name"
        end

      sql = +"SELECT #{columns.join(", ")} FROM #{klass.table_name}"
      sql << " WHERE #{where}"
      sql
    end

    def free_name(name, taken_names, max_length)
      (1..).each do |n|
        suffix = "_#{n}"
        candidate = "#{name[0, max_length - suffix.length]}#{suffix}"
        next if taken_names.include?(candidate.downcase)

        taken_names << candidate.downcase
        return candidate
      end
    end

    def copy_posts
      copy_model(Post, skip_processing: false, mapping: @posts)
      copy_model(PostAction, mapping: @post_actions)
      [PostReply, TopicLink, UserAction, QuotedPost].each { |k| copy_model(k) }
      [PostStat, IncomingEmail, PostDetail].each { |k| copy_model(k, skip_processing: true) }
      copy_model(PostRevision, mapping: @post_revisions)
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

      [GroupHistory, GroupTagNotificationDefault, GroupCategoryNotificationDefault].each do |k|
        col_list = k.columns.map { |c| "\"#{c.name}\"" }.join(", ")
        copy_model(
          k,
          select_sql:
            "SELECT #{col_list} FROM #{k.table_name} WHERE group_id NOT IN (#{@auto_group_ids.join(", ")})",
        )
      end

      [CategoryFeaturedTopic, CategoryFormTemplate, CategoryPostingReviewGroup].each do |k|
        copy_model(k)
      end

      # Copy custom fields
      [CategoryCustomField].each do |k|
        col_list = k.columns.map { |c| "\"#{c.name}\"" }.join(", ")
        copy_model(
          k,
          select_sql: "SELECT #{col_list} FROM #{k.table_name} WHERE name != 'import_id'",
        )
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
              @badges[row["id"].to_i] = existing.id
              next
            end

            old_id = row["id"].to_i
            row["id"] = (last_id += 1)
            @badges[old_id] = row["id"]

            row["badge_grouping_id"] = badge_grouping_id_from_imported_id(
              row["badge_grouping_id"],
            ) if row["badge_grouping_id"]

            row["image_upload_id"] = upload_id_from_imported_id(row["image_upload_id"])

            @raw_connection.put_copy_data(row.values)
          end
      end

      @sequences[Badge.sequence_name] = last_id + 1

      copy_model(UserBadge, is_a_user_model: true)
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
      topic_link["link_post_id"] = post_id_from_imported_id(
        topic_link["link_post_id"],
      ) if topic_link["link_post_id"]
      topic_link
    end

    def process_user_avatar(user_avatar)
      user_avatar["custom_upload_id"] = upload_id_from_imported_id(
        user_avatar["custom_upload_id"],
      ) if user_avatar["custom_upload_id"]
      user_avatar["gravatar_upload_id"] = upload_id_from_imported_id(
        user_avatar["gravatar_upload_id"],
      ) if user_avatar["gravatar_upload_id"]
      if user_avatar["custom_upload_id"].blank? && user_avatar["gravatar_upload_id"].blank?
        return nil
      end
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

    def process_oauth2_user_info(r)
      return nil if Oauth2UserInfo.where(uid: r["uid"], provider: r["provider"]).exists?
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

    def group_id_from_imported_id(id)
      @groups[id.to_i] unless id.nil?
    end

    def tag_id_from_imported_id(id)
      @tags[id.to_i]
    end

    def tag_group_id_from_imported_id(id)
      @tag_groups[id.to_i]
    end

    def upload_id_from_imported_id(id)
      @uploads[id.to_i]
    end

    def post_action_id_from_imported_id(id)
      @post_actions[id.to_i]
    end

    def badge_id_from_imported_id(id)
      @badges[id.to_i]
    end

    def badge_grouping_id_from_imported_id(id)
      @badge_groupings[id.to_i]
    end

    def notification_id_from_imported_id(id)
      @notifications[id.to_i]
    end

    def email_token_id_from_imported_id(id)
      @email_tokens[id.to_i]
    end

    def poll_id_from_imported_id(id)
      @polls[id.to_i]
    end

    def poll_option_id_from_imported_id(id)
      @poll_options[id.to_i]
    end

    def avatar_id_from_imported_id(id)
      @avatars[id.to_i]
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

    def copy_model_rows(
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
      processor = merger_processor_for(klass) unless skip_processing
      foreign_keys = foreign_key_maps(columns)

      query = select_sql || "SELECT #{quoted_columns(klass)} FROM #{klass.table_name}"
      selected = 0
      written = 0
      write_row =
        lambda do |row|
          @raw_connection.put_copy_data(columns.map { |column| row.fetch(column) })
          written += 1
          row
        end
      topic_links = TopicLinkRows.new(&write_row) if klass == TopicLink
      emit = topic_links || write_row
      @raw_connection.copy_data(copy_sql(klass), @encoder) do
        SourceRows.each_batch(source_raw_connection, query) do |rows|
          selected += rows.size
          rows.each do |row|
            if klass == PostRevision
              row["original_editor_id"] = normalize_author!(row, "post_revisions")
            end
            if row["user_id"]
              old_user_id = row["user_id"].to_i

              next if skip_if_merged && @merged_user_ids.include?(old_user_id)

              next if is_a_user_model && old_user_id < 1
              if old_user_id.positive?
                row["user_id"] = user_id_from_imported_id(old_user_id)
                next unless row["user_id"]
              end
              if klass == UserEmail && row["primary"] == "f" &&
                   UserEmail.exists?(email: row["email"])
                next
              end
            end

            foreign_keys.each { |column, ids| row[column] = ids[row[column].to_i] if row[column] }
            if !row["category_id"] && [CategoryCustomField, CategoryFeaturedTopic].include?(klass)
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
            if row["bookmarkable_id"]
              row["bookmarkable_id"] = post_id_from_imported_id(row["bookmarkable_id"]) if row[
                "bookmarkable_type"
              ] == "Post"
              row["bookmarkable_id"] = topic_id_from_imported_id(row["bookmarkable_id"]) if row[
                "bookmarkable_type"
              ] == "Topic"
            end

            if klass == Post
              source_post_id = Integer(row.fetch("id"))
              row["raw"] = references.rewrite(row["raw"], source_post_id: source_post_id)
              row["cooked"] = references.rewrite(
                row["cooked"],
                cooked: true,
                source_post_id: source_post_id,
              )
            elsif row["raw"] && row["topic_id"]
              row["raw"] = process_raw(row["raw"], row["topic_id"])
            end
            if klass == TopicLink && @configuration.preuploaded? &&
                 (url = references.rewrite(row["url"])) != row["url"]
              row["url"] = url
              row["domain"] = URI.parse(url).host || row["domain"]
            end
            next if klass == UserUpload && !row["upload_id"]
            if klass.table_name == "upload_references"
              next unless row["upload_id"]
              next unless remap_upload_reference_target(row)
            end

            if last_id
              old_id = row["id"].to_i
              row["source_revision_id"] = old_id if klass == PostRevision
              # Rows the processor skips below still consume an id; the gaps are harmless.
              row["id"] = (last_id += 1)
            end

            row = processor.call(ActiveSupport::HashWithIndifferentAccess.new(row)) if processor
            next unless row
            row = emit.call(row)
            if last_id
              imported_ids << old_id if has_custom_fields
              mapping[old_id] = row["id"] if mapping
            end
          end
        end
        topic_links&.flush
      end

      @sequences[klass.sequence_name] = last_id + 1 if last_id

      if has_custom_fields
        id_mapping_method_name = "#{klass.name.downcase}_id_from_imported_id"
        unless respond_to?(id_mapping_method_name)
          raise Error, "Missing ID mapping for #{klass.name}"
        end
        create_custom_fields(klass.name.downcase, "id", imported_ids) do |imported_id|
          { record_id: send(id_mapping_method_name, imported_id), value: imported_id }
        end
      end
      if klass == Post || selected >= 1000
        @progress&.say("Copied #{written} of #{selected} selected #{klass.table_name} rows")
      end
      [selected, written]
    end

    private

    def foreign_key_maps(columns)
      {
        "upload_id" => @uploads,
        "flair_upload_id" => @uploads,
        "uploaded_logo_id" => @uploads,
        "uploaded_logo_dark_id" => @uploads,
        "uploaded_background_id" => @uploads,
        "profile_background_upload_id" => @uploads,
        "card_background_upload_id" => @uploads,
        "group_id" => @groups,
        "flair_group_id" => @groups,
        "category_id" => @categories,
        "tag_id" => @tags,
        "tag_group_id" => @tag_groups,
        "deleted_by_id" => @users,
        "muted_user_id" => @users,
        "ignored_user_id" => @users,
        "badge_id" => @badges,
        "granted_title_badge_id" => @badges,
        "poll_id" => @polls,
        "poll_option_id" => @poll_options,
      }.slice(*columns)
    end

    def quoted_columns(klass)
      klass.column_names.map { |c| PG::Connection.quote_ident(c) }.join(",")
    end

    def copy_sql(klass)
      "COPY #{klass.table_name} (#{quoted_columns(klass)}) FROM STDIN"
    end

    def normalize_author!(row, table)
      original = row["user_id"]&.to_i
      return if !original || original <= 0 || @users[original]
      (@original_authors[table] ||= []) << { "id" => row.fetch("id").to_i, "user_id" => original }
      row["user_id"] = "-1"
      original
    end

    def remap_author!(row, table)
      normalize_author!(row, table)
      return if row["user_id"].nil? # Valid anonymized/deleted source identity.
      row["user_id"] = user_id_from_imported_id(row["user_id"])
      raise Error, "Unmapped #{table} author" if row["user_id"].nil?
    end
  end
end

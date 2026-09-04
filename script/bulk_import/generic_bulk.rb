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
  include HasSanitizableFields

  AVATAR_DIRECTORY = ENV["AVATAR_DIRECTORY"]
  UPLOAD_DIRECTORY = ENV["UPLOAD_DIRECTORY"]
  MERGE_IMPORT = ENV["MERGE_IMPORT"].present?
  DELTA_IMPORT = ENV["DELTA_IMPORT"].present?
  CONTENT_UPLOAD_REFERENCE_TYPES = %w[posts chat_messages]
  LAST_VIEWED_AT_PLACEHOLDER = "1970-01-01 00:00:00"

  def initialize(db_path, uploads_db_path = nil)
    self.class.validate_modes!(merge_import: MERGE_IMPORT, delta_import: DELTA_IMPORT)
    # SQLite would silently create an empty database for a mistyped path
    {
      "Intermediate database" => db_path,
      "Uploads database" => uploads_db_path,
    }.each { |label, path| raise "#{label} not found: #{path}" if path && !File.file?(path) }
    super()
    @source_db = create_connection(db_path)
    @uploads_db = create_connection(uploads_db_path) if uploads_db_path

    if MERGE_IMPORT
      row = @source_db.execute("SELECT value FROM config WHERE name = 'converting_from'").first
      @import_prefix = row&.[]("value")
      unless @import_prefix
        raise "MERGE_IMPORT requires 'converting_from' in intermediate DB config table"
      end
      puts "MERGE_IMPORT mode enabled with source prefix: #{@import_prefix}"
    elsif DELTA_IMPORT
      puts "DELTA_IMPORT mode enabled"
    end
  end

  def self.validate_modes!(merge_import:, delta_import:)
    return unless merge_import && delta_import

    raise "MERGE_IMPORT and DELTA_IMPORT cannot be enabled together"
  end

  def delta_import?
    DELTA_IMPORT
  end

  def preflight
    configure_unicode_usernames!

    return unless delta_import?

    puts "Running delta import preflight..."

    unless DB.query_single("SELECT to_regclass('public.migration_mappings')::TEXT").first
      raise "DELTA_IMPORT requires migration_mappings from a completed base import"
    end

    mappings = {
      groups: plain_import_mappings("group"),
      users: canonical_user_import_mappings,
      categories: plain_import_mappings("category"),
      topics: plain_import_mappings("topic"),
      posts: plain_import_mappings("post"),
    }
    if mappings.values.sum(&:size).zero?
      raise "DELTA_IMPORT requires existing plain numeric import_id mappings from a base import"
    end
    unless plain_mapped_core_record_exists?
      raise "DELTA_IMPORT requires at least one mapped core record from a base import"
    end

    errors = []
    preflight_users(mappings[:users], errors)
    preflight_groups(mappings[:groups], errors)
    preflight_categories(mappings, errors)
    preflight_topics(mappings, errors)
    preflight_posts(mappings, errors)

    report_delta_user_audit(
      @delta_preexisting_user_source_ids,
      "mapped users merge into pre-existing destination accounts " \
        "(identity verified by email) and will be updated",
    )
    report_delta_user_audit(
      @delta_username_conflict_source_ids,
      "mapped users keep their current usernames because the source username is taken",
    )
    report_delta_user_audit(
      @delta_unverified_user_source_ids,
      "mapped users have creation-date mismatches the delta cannot verify " \
        "(no email supplied) and will not be updated",
    )

    return if errors.empty?

    shown_errors = errors.first(25)
    suffix =
      (
        if errors.length > shown_errors.length
          "\n  ...and #{errors.length - shown_errors.length} more"
        else
          ""
        end
      )
    raise "Delta import preflight failed:\n  #{shown_errors.join("\n  ")}#{suffix}"
  end

  # non-ASCII source names require unicode_usernames before any name is
  # sanitized; the final value must be live before both the fresh import
  # and the delta preflight run
  def configure_unicode_usernames!
    if (allowlist = source_site_setting_value("allowed_unicode_username_characters"))
      SiteSetting.set_and_log(:allowed_unicode_username_characters, allowlist)
    end

    if (explicit = source_site_setting_value("unicode_usernames"))
      desired = %w[t true 1].include?(explicit.to_s.downcase)
      enable_unicode_usernames! if desired && !SiteSetting.unicode_usernames
      return
    end

    return if SiteSetting.unicode_usernames
    return unless source_has_non_ascii_names?

    enable_unicode_usernames!
    log_import_issue(
      "unicode_usernames auto-enabled",
      "source contains non-ASCII usernames or group names",
    )
  end

  def enable_unicode_usernames!
    raise <<~MSG if SiteSetting.external_system_avatars_url.blank?
        The source contains non-ASCII usernames, which requires enabling the
        'unicode_usernames' site setting, but its validator requires
        'external_system_avatars_url' to be set. Configure
        external_system_avatars_url on the destination site and re-run the import.
      MSG

    SiteSetting.set_and_log(:unicode_usernames, true)
    puts "Enabled unicode_usernames (non-ASCII names detected in source)"
  end

  def source_site_setting_value(name)
    query(
      "SELECT value FROM site_settings WHERE name = ? AND action = 'update' ORDER BY ROWID DESC LIMIT 1",
      name,
    ) { |rows| rows.first&.fetch("value", nil) }
  end

  def source_has_non_ascii_names?
    non_ascii = ->(value) { value.present? && !value.ascii_only? }
    user_columns = %w[username original_username] & table_column_names("users").to_a

    query("SELECT #{user_columns.join(", ")} FROM users") do |rows|
      rows.any? { |row| user_columns.any? { |column| non_ascii.call(row[column]) } }
    end ||
      query("SELECT name FROM groups") { |rows| rows.any? { |row| non_ascii.call(row["name"]) } }
  end

  def load_imported_ids
    super
    return unless delta_import?

    @delta_base_mappings = {
      groups: @groups.dup,
      users: @users.dup,
      categories: @categories.dup,
      topics: @topics.dup,
      posts: @posts.dup,
    }
    canonical_users = canonical_user_import_mappings
    if @delta_unverified_user_source_ids.present?
      canonical_users =
        canonical_users.reject do |source_id, _|
          @delta_unverified_user_source_ids.include?(source_id)
        end
    end
    @delta_update_mappings = @delta_base_mappings.merge(users: canonical_users)
  end

  def plain_import_mappings(name)
    DB.query(<<~SQL).to_h { |row| [Integer(row.value, 10), row.discourse_id.to_i] }
      SELECT value, #{name}_id AS discourse_id
        FROM #{name}_custom_fields
       WHERE name = 'import_id'
         AND value ~ '^[0-9]+$'
    SQL
  end

  def plain_mapped_core_record_exists?
    %w[group user category topic post].any? { |name| DB.query_single(<<~SQL).present? }
        SELECT 1
          FROM #{name}_custom_fields mapping
               JOIN #{name.pluralize} record ON record.id = mapping.#{name}_id
         WHERE mapping.name = 'import_id'
           AND mapping.value ~ '^[0-9]+$'
         LIMIT 1
      SQL
  end

  # A destination user can carry several source ids (base-import email merges,
  # alias merges); prefer the one this delta still exports so its updates apply.
  def canonical_user_import_mappings
    delta_source_ids =
      query("SELECT id FROM users") { |rows| rows.map { |row| row["id"].to_i }.to_set }
    rows = DB.query(<<~SQL)
      SELECT value, user_id AS discourse_id, created_at, id
        FROM user_custom_fields
       WHERE name = 'import_id'
         AND value ~ '^[0-9]+$'
       ORDER BY user_id, created_at, id
    SQL
    rows
      .group_by(&:discourse_id)
      .values
      .to_h do |mapping_rows|
        row =
          mapping_rows.find { |mapping| delta_source_ids.include?(Integer(mapping.value, 10)) } ||
            mapping_rows.first
        [Integer(row.value, 10), row.discourse_id.to_i]
      end
  end

  # The converter may consolidate several source accounts into one winner. The
  # optional user_aliases table lists those alias -> winner pairs so a delta can
  # merge destination accounts the base import created separately.
  def delta_user_aliases
    @delta_user_aliases ||=
      if table_column_names("user_aliases").any?
        query(
          "SELECT alias_user_id, canonical_user_id FROM user_aliases ORDER BY alias_user_id",
        ) { |rows| rows.map { |row| [row["alias_user_id"].to_i, row["canonical_user_id"].to_i] } }
      else
        []
      end
  end

  def delta_alias_accounts_by_canonical
    base_mappings = plain_import_mappings("user")
    delta_user_aliases.each_with_object(
      Hash.new { |hash, key| hash[key] = Set.new },
    ) do |(alias_id, canonical_id), result|
      account_id = base_mappings[alias_id]
      result[canonical_id] << account_id if account_id
    end
  end

  # Runs once before existing users are updated (both accounts came from the
  # base import) and once after the delta's new users, profiles, and stats
  # exist (the winner is new to this delta). Each pass is a no-op for pairs that
  # already share one account, so reruns are safe.
  def merge_delta_user_aliases
    pending_merges =
      delta_user_aliases.filter_map do |alias_source_id, canonical_source_id|
        source_id = user_id_from_imported_id(alias_source_id)
        target_id = user_id_from_imported_id(canonical_source_id)
        next if source_id.nil? || target_id.nil? || source_id == target_id

        source_user = User.unscoped.find_by(id: source_id)
        target_user = User.unscoped.find_by(id: target_id)
        next unless source_user && target_user

        [alias_source_id, canonical_source_id, source_user, target_user]
      end
    return if pending_merges.empty?

    # UserMerger inserts through ActiveRecord, but this run has COPYed rows with
    # importer-assigned ids that the sequences only learn about at the end.
    fix_primary_keys
    removed_users = pending_merges.map { |_, _, source_user, _| source_user }

    pending_merges.each do |alias_source_id, canonical_source_id, source_user, target_user|
      begin
        UserMerger.new(source_user, target_user).merge!
      rescue StandardError => e
        raise "Merging alias user #{alias_source_id} into user #{canonical_source_id} failed: #{e.message}"
      end

      # UserMerger keeps the target's own import_id and drops the alias's; keep
      # it on the survivor so reruns and later deltas still resolve the alias.
      UserCustomField.find_or_create_by!(
        user_id: target_user.id,
        name: "import_id",
        value: alias_source_id.to_s,
      )
      @users[alias_source_id] = target_user.id
      @delta_stats[:users][:updated_ids] << target_user.id if @delta_stats
    end

    # the merger's replacement addresses took ids above the importer's counter
    @last_user_email_id = last_id(UserEmail)
    refresh_user_lookup_caches(
      pending_merges.map { |_, _, _, target_user| target_user.id }.uniq,
      removed_users: removed_users,
    )

    merged_source_ids = pending_merges.map(&:first)
    shown_ids = merged_source_ids.first(20)
    suffix =
      (
        if merged_source_ids.length > shown_ids.length
          " +#{merged_source_ids.length - shown_ids.length} more"
        else
          ""
        end
      )
    puts "  Merged #{merged_source_ids.length} alias accounts into their winners (source IDs: #{shown_ids.join(", ")}#{suffix})"
  end

  def refresh_user_lookup_caches(user_ids, removed_users: [])
    removed_users.each do |user|
      @usernames_lower.delete(user.username_lower)
      @user_ids_by_username_lower.delete(user.username_lower)
      @usernames_by_id.delete(user.id)
      @user_full_names_by_id.delete(user.id)
    end

    user_ids.each_slice(10_000) do |ids|
      User
        .unscoped
        .where(id: ids)
        .pluck(:id, :username, :username_lower, :name)
        .each do |id, username, username_lower, name|
          @usernames_lower << username_lower
          @user_ids_by_username_lower[username_lower] = id
          @usernames_by_id[id] = username
          @user_full_names_by_id[id] = name if name.present?
        end
    end
    @emails = UserEmail.pluck(:email, :user_id).to_h
  end

  def delta_update_mapping(name)
    @delta_update_mappings.fetch(name)
  end

  def preflight_users(mappings, errors)
    @delta_preexisting_user_source_ids ||= Set.new
    @delta_unverified_user_source_ids ||= Set.new
    @delta_username_conflict_source_ids ||= Set.new
    return if mappings.empty?

    created_at_by_user_id = User.unscoped.pluck(:id, :created_at).to_h
    email_owners = UserEmail.pluck(Arel.sql("LOWER(email)"), :user_id).to_h
    username_owners = User.unscoped.pluck(:username_lower, :id).to_h
    username_lower_by_id = User.unscoped.pluck(:id, :username_lower).to_h
    alias_accounts = delta_alias_accounts_by_canonical
    seen_emails = {}
    seen_usernames = {}

    rows = query("SELECT * FROM users ORDER BY id")
    rows.each do |row|
      discourse_id = mappings[row["id"].to_i]
      next unless discourse_id

      created_at = created_at_by_user_id[discourse_id]
      unless created_at
        errors << "user #{row["id"]} maps to missing Discourse user #{discourse_id}"
        next
      end

      if immutable_time_changed?(row["created_at"], created_at)
        if row["email"].blank?
          # without an email the delta cannot re-verify the mapping, so the
          # account is left untouched instead of failing the run
          @delta_unverified_user_source_ids << row["id"].to_i
          next
        elsif email_owners[row["email"].downcase] == discourse_id
          # the base import merged this source user by email into an account
          # that predates it; the email match proves the mapping, so only the
          # creation-date check is waived and the account stays updatable
          @delta_preexisting_user_source_ids << row["id"].to_i
        else
          errors << "user #{row["id"]} changes immutable created_at"
        end
      end

      if row["email"].present?
        email = row["email"].downcase
        owner_id = email_owners[email]
        if owner_id && owner_id != discourse_id &&
             !alias_accounts.fetch(row["id"].to_i, Set.new).include?(owner_id)
          errors << "user #{row["id"]} email belongs to Discourse user #{owner_id}"
        end

        if (previous_source_id = seen_emails[email])
          errors << "user #{row["id"]} duplicates email of source user #{previous_source_id}"
        else
          seen_emails[email] = row["id"]
        end
      end

      if row["username"].present? &&
           !delta_username_unchanged?(row, discourse_id, username_lower_by_id[discourse_id]) &&
           (username = fix_name(row["username"])).present?
        normalized_username = User.normalize_username(username)
        owner_id = username_owners[normalized_username]
        if owner_id && owner_id != discourse_id
          # a taken username skips only the rename; failing the run would
          # block deltas on conflicts the source cannot resolve
          @delta_username_conflict_source_ids << row["id"].to_i
        elsif (previous_source_id = seen_usernames[normalized_username])
          errors << "user #{row["id"]} duplicates username of source user #{previous_source_id}"
        else
          seen_usernames[normalized_username] = row["id"]
        end
      end
    end
  ensure
    rows&.close
  end

  def report_delta_user_audit(set, description)
    return if set.blank?

    shown_ids = set.sort.first(20)
    hidden_count = set.size - shown_ids.size
    suffix = hidden_count > 0 ? " +#{hidden_count} more" : ""
    puts "Preflight: #{set.size} #{description} (source IDs: #{shown_ids.join(", ")}#{suffix})"
  end

  def imported_usernames_by_user_id
    @imported_usernames_by_user_id ||=
      UserCustomField.where(name: "import_username").pluck(:user_id, :value).to_h
  end

  # true when the source still carries the username the base import saw; the
  # destination may hold a deduplicated variant of it that must be kept
  def delta_username_unchanged?(row, discourse_id, destination_username_lower)
    source_username = row["original_username"].presence || row["username"]
    if User.normalize_username(imported_usernames_by_user_id[discourse_id]) ==
         User.normalize_username(source_username)
      return true
    end
    return false if destination_username_lower.blank?

    # the destination still carries the source username verbatim: the base
    # import kept it, so a stricter sanitizer must not rename it now
    return true if User.normalize_username(source_username) == destination_username_lower

    # suffix-deduplicated names are recorded nowhere when fix_name left the
    # name itself unchanged, so recognize the suffix pattern directly
    fixed = fix_name(row["username"])
    return false if fixed.blank?

    normalized = User.normalize_username(fixed)
    destination_username_lower.match?(/\A#{Regexp.escape(normalized)}_\d+\z/)
  end

  def preflight_groups(mappings, errors)
    return if mappings.empty?

    seen_names = {}
    rows = query("SELECT id, name, existing_id FROM groups ORDER BY id")
    rows.each do |row|
      next unless mappings.key?(row["id"].to_i)
      next if row["existing_id"].present?
      next if (name = fix_name(row["name"])).blank?

      name_lower = User.normalize_username(name)
      if (previous_source_id = seen_names[name_lower])
        errors << "group #{row["id"]} duplicates name of source group #{previous_source_id}"
      else
        seen_names[name_lower] = row["id"]
      end
    end
  ensure
    rows&.close
  end

  def preflight_categories(mappings, errors)
    return if mappings[:categories].empty?

    seen_names = {}
    rows = query("SELECT id, parent_category_id, name, existing_id FROM categories ORDER BY id")
    rows.each do |row|
      next unless mappings[:categories].key?(row["id"].to_i)
      next if row["existing_id"].present?
      next if row["name"].blank?

      if row["parent_category_id"].present?
        parent_id = mappings[:categories][row["parent_category_id"].to_i]
        # parents new in this delta cannot collide with updated names yet
        next unless parent_id
      end

      key = [parent_id, row["name"][0...50].scrub.strip]
      if (previous_source_id = seen_names[key])
        errors << "category #{row["id"]} duplicates name of source category #{previous_source_id}"
      else
        seen_names[key] = row["id"]
      end
    end
  ensure
    rows&.close
  end

  def preflight_topics(mappings, errors)
    return if mappings[:topics].empty?

    topics_by_id =
      Topic
        .unscoped
        .pluck(:id, :created_at, :archetype)
        .to_h { |id, created_at, archetype| [id, { created_at: created_at, archetype: archetype }] }
    topic_columns = table_column_names("topics")
    rows = query("SELECT * FROM topics ORDER BY id")
    rows.each do |row|
      discourse_id = mappings[:topics][row["id"].to_i]
      next unless discourse_id

      topic = topics_by_id[discourse_id]
      unless topic
        errors << "topic #{row["id"]} maps to missing Discourse topic #{discourse_id}"
        next
      end

      if immutable_time_changed?(row["created_at"], topic[:created_at])
        errors << "topic #{row["id"]} changes immutable created_at"
      end

      source_archetype =
        if topic_columns.include?("archetype")
          row["archetype"]
        elsif topic_columns.include?("private_message")
          row["private_message"].present? ? Archetype.private_message : Archetype.default
        end
      if source_archetype.present? && source_archetype != topic[:archetype]
        errors << "topic #{row["id"]} changes immutable archetype"
      end
    end
  ensure
    rows&.close
  end

  def preflight_posts(mappings, errors)
    return if mappings[:posts].empty?

    posts_by_id =
      Post
        .unscoped
        .pluck(:id, :created_at, :topic_id, :post_number, :reply_to_post_number)
        .to_h do |id, created_at, topic_id, post_number, reply_to_post_number|
          [
            id,
            {
              created_at: created_at,
              topic_id: topic_id,
              post_number: post_number,
              reply_to_post_number: reply_to_post_number,
            },
          ]
        end
    rows = query("SELECT * FROM posts ORDER BY id")
    rows.each do |row|
      discourse_id = mappings[:posts][row["id"].to_i]
      next unless discourse_id

      post = posts_by_id[discourse_id]
      unless post
        errors << "post #{row["id"]} maps to missing Discourse post #{discourse_id}"
        next
      end

      if immutable_time_changed?(row["created_at"], post[:created_at])
        errors << "post #{row["id"]} changes immutable created_at"
      end

      mapped_topic_id = mappings[:topics][row["topic_id"].to_i]
      errors << "post #{row["id"]} changes immutable topic" if mapped_topic_id != post[:topic_id]

      if row["post_number"].present? && row["post_number"].to_i != post[:post_number]
        errors << "post #{row["id"]} changes immutable post number"
      end

      next if row["reply_to_post_id"].blank?

      parent_id = mappings[:posts][row["reply_to_post_id"].to_i]
      parent_number = posts_by_id.dig(parent_id, :post_number)
      parent_number = nil if parent_number == 1
      if parent_number != post[:reply_to_post_number]
        errors << "post #{row["id"]} changes immutable reply parent"
      end
    end
  ensure
    rows&.close
  end

  def immutable_time_changed?(source_value, destination_value)
    source_value.present? &&
      to_datetime(source_value).to_time.to_i != destination_value.to_time.to_i
  end

  def start
    run # will call execute, and then "complete" the migration

    # Now that the migration is complete, do some more work:

    ENV["SKIP_USER_STATS"] = "1"
    Discourse::Application.load_tasks

    puts "running 'import:ensure_consistency' rake task."
    Rake::Task["import:ensure_consistency"].invoke

    # Force refresh directory items to sync user stats
    # This is needed even when enable_user_directory is false
    puts "", "Refreshing directory items and syncing user stats..."
    refresh_directory_items
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
    import_user_custom_fields
    import_user_followers

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
    import_category_moderation_groups
    update_category_read_restricted

    import_topics
    import_topic_custom_fields
    import_posts
    import_post_custom_fields

    import_polls
    import_poll_options
    import_poll_votes

    import_topic_tags
    import_topic_allowed_users
    import_topic_allowed_groups

    import_engagement
    import_post_voting_votes
    import_topic_voting_votes
    import_answers
    import_gamification_scores
    import_post_events

    import_badge_groupings
    import_badges
    import_user_badges
    import_anniversary_user_badges
    update_badge_grant_counts

    import_optimized_images

    import_topic_users
    update_topic_users
    import_bookmarks

    import_user_stats
    merge_delta_user_aliases if delta_import?

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
    report_delta_stats if delta_import?

    @source_db.close
    @uploads_db.close if @uploads_db
  end

  def refresh_directory_items
    start_time = Time.now

    # Force refresh all directory periods - this works even when
    # enable_user_directory site setting is disabled
    DirectoryItem.period_types.each_key do |period|
      puts "  Refreshing directory items for period: #{period}"
      DirectoryItem.refresh_period!(period, force: true)
    end

    UserStat.ensure_consistency!
    Discourse.cache.clear
    Site.clear_cache

    puts "  Refreshed directory items in #{(Time.now - start_time).to_i} seconds."
  end

  def start_delta_entity(entity, table, mapping, last_destination_id)
    return unless delta_import?

    source_ids = query("SELECT id FROM #{table}") { |rows| rows.map { |row| row["id"].to_i } }
    base_mapping = @delta_base_mappings.fetch(mapping)
    @delta_stats ||= {}
    @delta_stats[entity] = {
      mapped: source_ids.count { |source_id| base_mapping.key?(source_id) },
      unmapped_ids: source_ids.reject { |source_id| base_mapping.key?(source_id) },
      last_destination_id: last_destination_id,
      updated_ids: Set.new,
    }
  end

  def finish_delta_entity(entity, mapping)
    return unless delta_import?

    stats = @delta_stats.fetch(entity)
    destination_mapping = instance_variable_get("@#{mapping}")
    stats[:deduplicated_ids] = stats[:unmapped_ids]
      .select do |source_id|
        destination_id = destination_mapping[source_id]
        destination_id && destination_id <= stats[:last_destination_id]
      end
      .to_set
    stats[:deduplicated] = stats[:deduplicated_ids].size
    stats[:new] = stats[:unmapped_ids].count do |source_id|
      destination_id = destination_mapping[source_id]
      destination_id && destination_id > stats[:last_destination_id]
    end
    stats[:updated] = stats[:updated_ids].size
    stats[:unchanged] = stats[:mapped] - stats[:updated]
  end

  def delta_deduplicated_source_id?(entity, source_id)
    return false unless delta_import?

    source_id = source_id.to_i
    return true if @delta_stats.dig(entity, :deduplicated_ids)&.include?(source_id)

    entity == :users && @delta_base_mappings[:users].key?(source_id) &&
      !delta_update_mapping(:users).key?(source_id)
  end

  def record_delta_updates(entity, result)
    return unless delta_import?

    @delta_stats.fetch(entity)[:updated_ids].merge(result[:updated_keys].map(&:to_i))
  end

  def update_records(rows, name, columns, keys: [:id])
    result = super
    track_delta_column_changes(name, result) if delta_import?
    result
  end

  def track_delta_column_changes(name, result)
    @delta_column_changes ||=
      Hash.new { |hash, key| hash[key] = { total: 0, columns: Hash.new(0) } }
    entry = @delta_column_changes[name.to_s.pluralize]
    entry[:total] += result[:total]
    result[:changed_counts].each { |column, count| entry[:columns][column] += count }
  end

  def report_delta_stats
    puts "", "Delta import summary:"
    @delta_stats.each do |entity, stats|
      stats[:updated] = stats[:updated_ids].size
      stats[:unchanged] = stats[:mapped] - stats[:updated]
      puts "  #{entity}: mapped=#{stats[:mapped]}, new=#{stats[:new]}, " \
             "unchanged=#{stats[:unchanged]}, updated=#{stats[:updated]}, " \
             "deduplicated=#{stats[:deduplicated]}"
    end

    report_delta_column_changes
  end

  def report_delta_column_changes
    return if @delta_column_changes.blank?

    printed_header = false
    @delta_column_changes.sort.each do |table, entry|
      columns = entry[:columns].select { |_, count| count > 0 }.sort_by { |_, count| -count }
      next if columns.empty?

      unless printed_header
        puts "", "Delta column updates:"
        printed_header = true
      end
      puts "  #{table} (#{entry[:total]} candidate rows):"
      columns.each do |column, count|
        share = entry[:total] > 0 ? (count * 100.0 / entry[:total]).round : 0
        flag =
          if count >= 100 && share >= 50
            "  <-- #{share}% of rows; verify the source really changed " \
              "(an export-side default may have changed)"
          else
            ""
          end
        puts "    #{column}: #{count}#{flag}"
      end
    end
  end

  def upsert_delta_custom_fields(entity, mapping_name, anonymized_filter: false)
    foreign_key = "#{entity}_id"
    source_table = "#{entity}_custom_fields"
    sql = "SELECT fields.* FROM #{source_table} fields"
    if anonymized_filter
      sql += " JOIN users source_users ON source_users.id = fields.user_id"
      sql += " WHERE source_users.anonymized IS NOT TRUE"
    end

    rows = query(sql)
    updates_by_key = {}
    rows.each do |row|
      next if row["value"].nil?

      discourse_id = delta_update_mapping(mapping_name)[row[foreign_key].to_i]
      next unless discourse_id

      update = { foreign_key.to_sym => discourse_id, :name => row["name"], :value => row["value"] }
      updates_by_key[[discourse_id, row["name"]]] = update
    end
    result =
      update_records(
        updates_by_key.values,
        "#{entity}_custom_field",
        [:value],
        keys: [foreign_key.to_sym, :name],
      )
    @delta_stats[mapping_name][:updated_ids].merge(
      result[:updated_keys].map { |key| key.first.to_i },
    )
  ensure
    rows&.close
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

    return if ENV["SKIP_MIGRATED_SITE_FLAG_UPDATE"]

    # Bypassing SiteSetting.set_and_log if migrated_site is present and not enabled, enable it
    # We don't need to have the plugin enabled
    migrated_site_flag_enabled = DB.exec(<<~SQL) > 0
      UPDATE site_settings
         SET value = 't'
       WHERE name = 'migrated_site'
         AND value <> 't'
    SQL

    SiteSetting.refresh! if migrated_site_flag_enabled
  end

  def import_categories
    puts "", "Importing categories..."

    start_delta_entity(:categories, "categories", :categories, @last_category_id)
    update_delta_categories if delta_import?

    categories = query(<<~SQL)
        WITH
          RECURSIVE
          tree AS (
                    SELECT c.id, c.parent_category_id, c.name, c.description, c.color, c.text_color,
                           c.slug, c.existing_id, c.position, c.logo_upload_id, 0 AS level, c.show_subcategory_list, c.subcategory_list_style, c.minimum_required_tags
                      FROM categories c
                     WHERE c.parent_category_id IS NULL
                     UNION ALL
                    SELECT c.id, c.parent_category_id, c.name, c.description, c.color, c.text_color,
                           c.slug, c.existing_id, c.position, c.logo_upload_id, tree.level + 1 AS level,
                           c.show_subcategory_list, c.subcategory_list_style, c.minimum_required_tags
                      FROM categories c,
                           tree
                     WHERE c.parent_category_id = tree.id
                  )
      SELECT id, parent_category_id, name, description, color, text_color, slug, existing_id, logo_upload_id, show_subcategory_list, subcategory_list_style, minimum_required_tags,
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
          (
            if row["parent_category_id"]
              category_id_from_imported_id(row["parent_category_id"])
            else
              nil
            end
          ),
        slug: row["slug"],
        uploaded_logo_id:
          (
            if row["logo_upload_id"]
              upload_id_from_original_id(row["logo_upload_id"])
            else
              nil
            end
          ),
        show_subcategory_list: row["show_subcategory_list"],
        subcategory_list_style: row["subcategory_list_style"],
        minimum_required_tags: row["minimum_required_tags"],
        color: row["color"],
        text_color: row["text_color"],
      }
    end

    categories.close
    update_delta_category_parents if delta_import?
    finish_delta_entity(:categories, :categories)
  end

  # second pass: parents that were only created by this delta are resolvable
  # after create_categories has run
  def update_delta_category_parents
    rows = query(<<~SQL)
      SELECT id, parent_category_id, existing_id
        FROM categories
       WHERE parent_category_id IS NOT NULL
       ORDER BY id
    SQL
    updates =
      rows.filter_map do |row|
        discourse_id = delta_update_mapping(:categories)[row["id"].to_i]
        next unless discourse_id
        next if row["existing_id"].present?

        parent_id = category_id_from_imported_id(row["parent_category_id"])
        next unless parent_id

        { id: discourse_id, parent_category_id: parent_id }
      end
    result = update_records(updates, "category", [:parent_category_id])
    record_delta_updates(:categories, result)
  ensure
    rows&.close
  end

  def update_delta_categories
    columns = %i[
      name
      name_lower
      slug
      user_id
      description
      position
      parent_category_id
      uploaded_logo_id
      show_subcategory_list
      subcategory_list_style
      minimum_required_tags
      color
      text_color
    ]
    source_columns = table_column_names("categories")
    rows = query("SELECT * FROM categories ORDER BY id")
    updates =
      rows.filter_map do |row|
        discourse_id = delta_update_mapping(:categories)[row["id"].to_i]
        next unless discourse_id
        next if row["existing_id"].present?

        update = { id: discourse_id }
        if row["name"].present?
          update[:name] = row["name"][0...50].scrub.strip
          update[:name_lower] = update[:name].downcase
        end
        update[:slug] = row["slug"] if source_columns.include?("slug")
        if source_columns.include?("user_id") && row["user_id"].present?
          update[:user_id] = user_id_from_imported_id(row["user_id"])
        end
        update[:description] = row["description"] if source_columns.include?("description")
        update[:position] = row["position"] if source_columns.include?("position")
        if row["parent_category_id"].present?
          update[:parent_category_id] = category_id_from_imported_id(row["parent_category_id"])
        end
        if row["logo_upload_id"].present?
          update[:uploaded_logo_id] = upload_id_from_original_id(row["logo_upload_id"])
        end
        %i[
          show_subcategory_list
          subcategory_list_style
          minimum_required_tags
          color
          text_color
        ].each do |column|
          update[column] = row[column.to_s] if source_columns.include?(column.to_s)
        end
        update
      end
    result = update_records(updates, "category", columns)
    record_delta_updates(:categories, result)
  ensure
    rows&.close
  end

  def import_category_about_topics
    puts "", %|Creating "About..." topics for categories...|
    start_time = Time.now
    Category.ensure_consistency!
    Site.clear_cache

    categories = query(<<~SQL)
      SELECT id, about_topic_title, existing_id
        FROM categories
       WHERE about_topic_title IS NOT NULL
       ORDER BY id
    SQL

    categories.each do |row|
      next if delta_import? && row["existing_id"].present?

      if (about_topic_title = row["about_topic_title"]).present?
        if (category_id = category_id_from_imported_id(row["id"]))
          topic = Category.find(category_id).topic
          if delta_import? && topic.title != about_topic_title
            @delta_stats[:categories][:updated_ids] << category_id
          end
          topic.title = about_topic_title
          topic.save!(validate: false)
        end
      end
    end

    categories.close

    puts "  Creating took #{(Time.now - start_time).to_i} seconds."
  end

  def import_category_custom_fields
    puts "", "Importing category custom fields..."

    upsert_delta_custom_fields(:category, :categories) if delta_import?

    category_custom_fields = query(<<~SQL)
      SELECT *
      FROM category_custom_fields
      ORDER BY category_id, name
    SQL

    field_names =
      query("SELECT DISTINCT name FROM category_custom_fields") { it.map { |row| row["name"] } }
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
      SELECT c.id AS category_id,
            p.value -> 'group_id' AS group_id,
            p.value -> 'existing_group_id' AS existing_group_id,
            p.value -> 'permission_type' AS permission_type
      FROM categories c,
          JSON_EACH(c.permissions) p
    SQL

    existing_category_group_ids = CategoryGroup.pluck(:category_id, :group_id).to_set

    if delta_import?
      permission_updates =
        permissions.filter_map do |row|
          category_id = category_id_from_imported_id(row["category_id"])
          # JSON `->` yields TEXT in SQLite; keep IDs comparable with pluck results
          group_id = row["existing_group_id"]&.to_i || group_id_from_imported_id(row["group_id"])
          next unless category_id && group_id && !row["permission_type"].nil?
          next if existing_category_group_ids.exclude?([category_id, group_id])

          { category_id: category_id, group_id: group_id, permission_type: row["permission_type"] }
        end
      result =
        update_records(
          permission_updates,
          "category_group",
          [:permission_type],
          keys: %i[category_id group_id],
        )
      @delta_stats[:categories][:updated_ids].merge(
        result[:updated_keys].map { |key| key.first.to_i },
      )
      permissions.close
      permissions = query(<<~SQL)
        SELECT c.id AS category_id,
              p.value -> 'group_id' AS group_id,
              p.value -> 'existing_group_id' AS existing_group_id,
              p.value -> 'permission_type' AS permission_type
        FROM categories c,
            JSON_EACH(c.permissions) p
      SQL
    end

    create_category_groups(permissions) do |row|
      category_id = category_id_from_imported_id(row["category_id"])
      group_id = row["existing_group_id"]&.to_i || group_id_from_imported_id(row["group_id"])
      next if existing_category_group_ids.include?([category_id, group_id])

      { category_id: category_id, group_id: group_id, permission_type: row["permission_type"] }
    end

    permissions.close
  end

  def import_category_moderation_groups
    puts "", "Importing category moderation groups..."

    moderation_groups = query(<<~SQL)
      SELECT c.id AS category_id,
            m.value AS group_id
      FROM categories c,
           JSON_EACH(c.moderation_group_ids) m
      ORDER BY c.id, m.value
    SQL

    existing_moderation_groups = CategoryModerationGroup.pluck(:category_id, :group_id).to_set

    create_category_moderation_groups(moderation_groups) do |row|
      category_id = category_id_from_imported_id(row["category_id"])
      group_id = group_id_from_imported_id(row["group_id"])

      next unless category_id && group_id
      next unless existing_moderation_groups.add?([category_id, group_id])

      { category_id: category_id, group_id: group_id }
    end

    moderation_groups.close
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

  def update_category_read_restricted
    puts "", "Updating category read_restricted flags..."
    start_time = Time.now
    processed_count = 0
    updated_count = 0
    skipped_count = 0

    Category
      .includes(category_groups: :group)
      .find_each do |category|
        processed_count += 1

        permissions = {}
        category.category_groups.each do |category_group|
          group = category_group.group
          permissions[category_group.group_name] = category_group.permission_type if group.present?
        end

        expected_read_restricted =
          if permissions.empty?
            false
          else
            Category.resolve_permissions(permissions).first
          end

        current_read_restricted = category.read_restricted

        if current_read_restricted != expected_read_restricted
          category.update_column(:read_restricted, expected_read_restricted)
          updated_count += 1
        else
          skipped_count += 1
        end
      end

    puts "  Update took #{(Time.now - start_time).to_i} seconds. Processed: #{processed_count}, Updated: #{updated_count}, Skipped: #{skipped_count}."
  end

  def import_groups
    puts "", "Importing groups..."

    start_delta_entity(:groups, "groups", :groups, @last_group_id)
    update_delta_groups if delta_import?

    groups = query(<<~SQL)
      SELECT *
      FROM groups
      ORDER BY id
    SQL

    create_groups(groups) do |row|
      next if group_id_from_imported_id(row["id"]).present?

      {
        imported_id: row["id"],
        existing_id: row["existing_id"],
        name: row["name"],
        full_name: row["full_name"],
        public_admission: row["public_admission"] || false,
        public_exit: row["public_exit"] || false,
        allow_membership_requests: row["allow_membership_requests"] || false,
        visibility_level: row["visibility_level"],
        members_visibility_level: row["members_visibility_level"],
        mentionable_level: row["mentionable_level"],
        messageable_level: row["messageable_level"],
        assignable_level: row["assignable_level"],
      }
    end

    groups.close
    finish_delta_entity(:groups, :groups)
  end

  def update_delta_groups
    columns = %i[
      name
      full_name
      title
      bio_raw
      bio_cooked
      public_admission
      public_exit
      allow_membership_requests
      visibility_level
      members_visibility_level
      mentionable_level
      messageable_level
    ]
    columns << :assignable_level if GROUP_COLUMNS.include?(:assignable_level)
    rows = query("SELECT * FROM groups ORDER BY id")
    updates =
      rows.filter_map do |row|
        discourse_id = delta_update_mapping(:groups)[row["id"].to_i]
        next unless discourse_id
        next if row["existing_id"].present?

        update = { id: discourse_id }
        columns.each { |column| update[column] = row[column.to_s] }
        if update[:name].present?
          fixed_name = fix_name(update[:name])
          if fixed_name.present?
            update[:name] = fixed_name
          else
            update.delete(:name)
            log_import_issue(
              "group name sanitized to blank, name kept",
              "group #{row["id"]} #{row["name"].inspect}",
            )
          end
        end
        update[:bio_raw] = row["description"] unless row["description"].nil?
        update[:bio_cooked] = pre_cook(update[:bio_raw]) unless update[:bio_raw].nil?
        update
      end
    result = update_records(updates, "group", columns)
    record_delta_updates(:groups, result)
    Group
      .where(id: updates.map { |update| update[:id] })
      .pluck(:name)
      .each { |name| @group_names_lower << User.normalize_username(name) }
  ensure
    rows&.close
  end

  def import_group_members
    puts "", "Importing group members..."

    group_members = query(<<~SQL)
      SELECT *
      FROM group_members
      ORDER BY ROWID
    SQL

    existing_group_user_ids = GroupUser.pluck(:group_id, :user_id).to_set

    if delta_import?
      ownership_updates =
        group_members.filter_map do |row|
          group_id = group_id_from_imported_id(row["group_id"])
          user_id = user_id_from_imported_id(row["user_id"])
          next unless group_id && user_id && !row["owner"].nil?
          next if existing_group_user_ids.exclude?([group_id, user_id])

          { group_id: group_id, user_id: user_id, owner: row["owner"] }
        end
      update_records(ownership_updates, "group_user", [:owner], keys: %i[group_id user_id])
      group_members.close
      group_members = query("SELECT * FROM group_members ORDER BY ROWID")
    end

    create_group_users(group_members) do |row|
      group_id = group_id_from_imported_id(row["group_id"])
      user_id = user_id_from_imported_id(row["user_id"])

      next if user_id.nil?
      next if group_id.nil?
      next unless existing_group_user_ids.add?([group_id, user_id])

      { group_id: group_id, user_id: user_id, owner: row["owner"] }
    end

    group_members.close
  end

  def import_users
    puts "", "Importing users..."

    start_delta_entity(:users, "users", :users, @last_user_id)
    if delta_import?
      merge_delta_user_aliases
      update_delta_users
    end

    users = query(<<~SQL)
      SELECT *
      FROM users
      ORDER BY id
    SQL

    create_users(users) do |row|
      next if user_id_from_imported_id(row["id"]).present?

      if row["suspension"].present?
        suspension = JSON.parse(row["suspension"])
        suspended_at = suspension["suspended_at"]
        suspended_till = suspension["suspended_till"]
      end

      if row["anonymized"] == 1
        row["username"] = "anon_#{anon_username_suffix}"
        row["email"] = "#{row["username"]}#{UserAnonymizer::EMAIL_SUFFIX}"
        row["name"] = nil
        row["ip_address"] = nil
        row["registration_ip_address"] = nil
        row["date_of_birth"] = nil
        row["title"] = nil
        row["sso_record"] = nil
      end

      sso_record = JSON.parse(row["sso_record"]) if row["sso_record"].present?

      {
        imported_id: row["id"],
        username: row["username"],
        original_username: row["original_username"],
        name: row["name"],
        email: row["email"],
        locale: row["locale"],
        external_id: sso_record&.fetch("external_id", nil),
        persist_imported_username: row["anonymized"] != 1,
        created_at: to_datetime(row["created_at"]),
        staged: row["staged"],
        last_seen_at: to_datetime(row["last_seen_at"]),
        admin: row["admin"],
        moderator: row["moderator"],
        approved: row["approved"].nil? ? nil : row["approved"] == 1,
        approved_at: to_datetime(row["approved_at"]),
        approved_by_id: user_id_from_imported_id(row["approved_by_id"]),
        suspended_at: suspended_at,
        suspended_till: suspended_till,
        trust_level: row["trust_level"],
        manual_locked_trust_level: row["manual_locked_trust_level"],
        ip_address: row["ip_address"],
        registration_ip_address: row["registration_ip_address"],
        date_of_birth: to_date(row["date_of_birth"]),
        primary_group_id: group_id_from_imported_id(row["primary_group_id"]),
        title: row["title"],
      }
    end

    users.close
    finish_delta_entity(:users, :users)
  end

  def update_delta_users
    destination_users = User.unscoped.where(id: delta_update_mapping(:users).values).index_by(&:id)
    columns = %i[
      username
      username_lower
      name
      locale
      title
      staged
      admin
      moderator
      trust_level
      manual_locked_trust_level
      primary_group_id
      suspended_at
      suspended_till
      last_seen_at
    ]
    rows = query("SELECT * FROM users ORDER BY id")
    updates = []
    email_updates = []
    primary_emails =
      UserEmail.where(user_id: delta_update_mapping(:users).values, primary: true).index_by(
        &:user_id
      )

    rows.each do |row|
      discourse_id = delta_update_mapping(:users)[row["id"].to_i]
      next unless discourse_id
      next if row["anonymized"] == 1

      destination_user = destination_users[discourse_id]
      update = { id: discourse_id }
      if row["username"].present? &&
           !@delta_username_conflict_source_ids.include?(row["id"].to_i) &&
           !delta_username_unchanged?(row, discourse_id, destination_user&.username_lower) &&
           (username = fix_name(row["username"])).present?
        update[:username] = username
        update[:username_lower] = User.normalize_username(username)
      end
      %i[
        name
        locale
        title
        staged
        admin
        moderator
        trust_level
        manual_locked_trust_level
      ].each { |column| update[column] = row[column.to_s] }
      if row["primary_group_id"].present?
        update[:primary_group_id] = group_id_from_imported_id(row["primary_group_id"])
      end
      if row["last_seen_at"].present?
        source_last_seen_at = to_datetime(row["last_seen_at"])
        update[:last_seen_at] = [destination_user&.last_seen_at, source_last_seen_at].compact.max
      end

      if row["suspension"].present?
        suspension = JSON.parse(row["suspension"])
        source_start = to_datetime(suspension["suspended_at"])
        source_end = to_datetime(suspension["suspended_till"])
        update[:suspended_at] = destination_user&.suspended_at || source_start || Time.zone.now
        update[:suspended_till] = [destination_user&.suspended_till, source_end].compact.max ||
          200.years.from_now
      end
      updates << update

      if row["email"].present? && (primary_email = primary_emails[discourse_id]) &&
           !primary_email.email.casecmp?(row["email"])
        email = row["email"].downcase
        if EmailAddressValidator.valid_value?(email)
          # UserMerger may have moved the address over as a secondary email
          UserEmail.where(user_id: discourse_id, email:).where.not(id: primary_email.id).delete_all
          email_updates << { id: primary_email.id, user_id: discourse_id, email: email }
        else
          log_import_issue("invalid email update skipped", "user #{row["id"]}")
        end
      end
    end

    result = update_records(updates, "user", columns)
    record_delta_updates(:users, result)
    updated_user_ids_by_email_id = email_updates.to_h { |update| [update[:id], update[:user_id]] }
    email_result = update_records(email_updates, "user_email", [:email])
    @delta_stats[:users][:updated_ids].merge(
      email_result[:updated_keys].filter_map { |id| updated_user_ids_by_email_id[id.to_i] },
    )

    User
      .unscoped
      .where(id: updates.map { |update| update[:id] })
      .find_each do |user|
        @usernames_lower << user.username_lower
        @user_ids_by_username_lower[user.username_lower] = user.id
        @usernames_by_id[user.id] = user.username
        @user_full_names_by_id[user.id] = user.name if user.name.present?
      end
    @emails = UserEmail.pluck(:email, :user_id).to_h
  ensure
    rows&.close
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
      next if delta_deduplicated_source_id?(:users, row["id"])
      next unless user_id && existing_user_ids.add?(user_id)

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

    update_delta_user_profiles if delta_import?

    users = query(<<~SQL)
      SELECT id, bio, location, website, anonymized
      FROM users
      ORDER BY id
    SQL

    existing_user_ids = UserProfile.pluck(:user_id).to_set

    create_user_profiles(users) do |row|
      user_id = user_id_from_imported_id(row["id"])
      next if delta_deduplicated_source_id?(:users, row["id"])
      next unless user_id && existing_user_ids.add?(user_id)

      if row["anonymized"] == 1
        row["bio"] = nil
        row["location"] = nil
        row["website"] = nil
      end

      { user_id: user_id, bio_raw: row["bio"], location: row["location"], website: row["website"] }
    end

    users.close
  end

  def update_delta_user_profiles
    rows = query("SELECT id, bio, location, website, anonymized FROM users ORDER BY id")
    updates =
      rows.filter_map do |row|
        user_id = delta_update_mapping(:users)[row["id"].to_i]
        next unless user_id
        next if row["anonymized"] == 1

        update = {
          user_id: user_id,
          location: row["location"],
          website: row["website"],
          bio_raw: row["bio"],
        }
        update[:bio_cooked] = pre_cook(row["bio"].scrub.strip) unless row["bio"].nil?
        update
      end
    result =
      update_records(
        updates,
        "user_profile",
        %i[location website bio_raw bio_cooked],
        keys: [:user_id],
      )
    @delta_stats[:users][:updated_ids].merge(result[:updated_keys].map(&:to_i))
  ensure
    rows&.close
  end

  def import_user_options
    puts "", "Importing user options..."

    update_delta_user_options if delta_import?

    users_columns = table_column_names("users")
    hide_profile_columns = %w[hide_profile_and_presence hide_profile hide_presence]
    available_hide_profile_columns =
      hide_profile_columns.select { |column| users_columns.include?(column) }
    select_hide_profile_columns =
      hide_profile_columns.map do |column|
        available_hide_profile_columns.include?(column) ? column : "NULL AS #{column}"
      end

    users = query(<<~SQL)
      SELECT id, timezone, email_level, email_messages_level, email_digests, anonymized,
             #{select_hide_profile_columns.join(", ")}
        FROM users
       WHERE anonymized IS TRUE
          OR timezone IS NOT NULL
          OR email_level IS NOT NULL
          OR email_messages_level IS NOT NULL
          OR email_digests IS NOT NULL
          #{available_hide_profile_columns.map { |column| "OR #{column} IS NOT NULL" }.join("\n          ")}
       ORDER BY id
    SQL

    existing_user_ids = UserOption.pluck(:user_id).to_set

    create_user_options(users) do |row|
      user_id = user_id_from_imported_id(row["id"])
      next if delta_deduplicated_source_id?(:users, row["id"])
      next unless user_id && existing_user_ids.add?(user_id)

      if row["anonymized"] == 1
        row["mailing_list_mode"] = false
        row["email_digests"] = false
        row["email_level"] = UserOption.email_level_types[:never]
        row["email_messages_level"] = UserOption.email_level_types[:never]
      end

      options = {
        user_id: user_id,
        timezone: row["timezone"],
        email_level: row["email_level"],
        email_messages_level: row["email_messages_level"],
        email_digests: row["email_digests"],
        hide_profile: row["hide_profile"],
        hide_presence: row["hide_presence"],
      }
      options[:mailing_list_mode] = row["mailing_list_mode"] if !row["mailing_list_mode"].nil?
      options[:hide_profile_and_presence] = row["hide_profile_and_presence"] if !row[
        "hide_profile_and_presence"
      ].nil?

      options
    end

    users.close
  end

  def update_delta_user_options
    source_columns = table_column_names("users")
    columns = USER_OPTION_COLUMNS.reject { |column| column == :user_id }
    columns.select! { |column| source_columns.include?(column.to_s) }
    return if columns.empty?

    # the combined flag is mirrored into the split columns below, even when the
    # source schema predates the split
    columns |= %i[hide_profile hide_presence] if columns.include?(:hide_profile_and_presence)

    rows = query("SELECT * FROM users ORDER BY id")
    updates =
      rows.filter_map do |row|
        user_id = delta_update_mapping(:users)[row["id"].to_i]
        next unless user_id
        next if row["anonymized"] == 1

        update = { user_id: user_id }
        columns.each { |column| update[column] = row[column.to_s] }
        if !update[:hide_profile_and_presence].nil?
          update[:hide_profile] = update[:hide_presence] = update[:hide_profile_and_presence]
        end
        update
      end
    result = update_records(updates, "user_option", columns, keys: [:user_id])
    @delta_stats[:users][:updated_ids].merge(result[:updated_keys].map(&:to_i))
  ensure
    rows&.close
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

    update_delta_user_field_values(field_id_mapping) if delta_import?

    values = query(<<~SQL)
      SELECT v.*
        FROM user_field_values v
             JOIN users u ON v.user_id = u.id
       WHERE u.anonymized IS NOT TRUE
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

  def update_delta_user_field_values(field_id_mapping)
    rows = query(<<~SQL)
      SELECT v.*
        FROM user_field_values v
             JOIN users u ON v.user_id = u.id
       WHERE u.anonymized IS NOT TRUE
    SQL
    updates_by_key = {}
    rows.each do |row|
      next if row["value"].nil?

      user_id = delta_update_mapping(:users)[row["user_id"].to_i]
      field_name = field_id_mapping[row["field_id"]]
      next unless user_id && field_name

      update = { user_id: user_id, name: field_name, value: row["value"] }
      updates_by_key[[user_id, field_name]] = update
    end
    result =
      update_records(updates_by_key.values, "user_custom_field", [:value], keys: %i[user_id name])
    @delta_stats[:users][:updated_ids].merge(result[:updated_keys].map { |key| key.first.to_i })
  ensure
    rows&.close
  end

  def import_single_sign_on_records
    puts "", "Importing SSO records..."

    users = query(<<~SQL)
      SELECT id, sso_record
      FROM users
      WHERE sso_record IS NOT NULL
        AND anonymized IS NOT TRUE
      ORDER BY id
    SQL

    existing_user_ids = SingleSignOnRecord.pluck(:user_id).to_set

    create_single_sign_on_records(users) do |row|
      user_id = user_id_from_imported_id(row["id"])
      next unless user_id && existing_user_ids.add?(user_id)

      sso_record = JSON.parse(row["sso_record"], symbolize_names: true)
      sso_record[:user_id] = user_id
      sso_record
    end

    users.close
  end

  def import_user_associated_accounts
    puts "", "Importing user associated accounts..."

    update_delta_user_associated_accounts if delta_import?

    accounts = query(<<~SQL)
      SELECT a.*, COALESCE(u.last_seen_at, u.created_at) AS last_used_at, u.email, u.username
        FROM user_associated_accounts a
             JOIN users u ON u.id = a.user_id
       WHERE u.anonymized IS NOT TRUE
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

  # Source and destination share the identity provider, so the source's current
  # provider UID wins over whichever destination account still holds it,
  # including the userless rows UserMerger leaves behind.
  def update_delta_user_associated_accounts
    wanted_by_identity = {}
    users_by_account_id = {}
    rows = query(<<~SQL)
      SELECT a.user_id, a.provider_name, a.provider_uid
        FROM user_associated_accounts a
             JOIN users u ON u.id = a.user_id
       WHERE u.anonymized IS NOT TRUE
       ORDER BY a.user_id, a.provider_name
    SQL
    rows.each do |row|
      user_id = user_id_from_imported_id(row["user_id"])
      wanted_by_identity[[row["provider_name"], row["provider_uid"]]] = user_id if user_id
    end

    # rows whose identity the delta gives to someone else go first, so both
    # unique indexes stay satisfied; a user left without a row is created by
    # the regular loop below, which also covers two users swapping identities
    displaced_ids = []
    current_by_user = {}
    UserAssociatedAccount
      .pluck(:id, :user_id, :provider_name, :provider_uid)
      .each do |id, user_id, provider_name, provider_uid|
        wanted_by = wanted_by_identity[[provider_name, provider_uid]]
        if wanted_by && wanted_by != user_id
          log_import_issue(
            "associated account reassigned",
            "#{provider_name}/#{provider_uid} moved from user #{user_id.inspect} to user #{wanted_by}",
          )
          displaced_ids << id
        elsif user_id
          current_by_user[[user_id, provider_name]] = [id, provider_uid]
        end
      end
    displaced_ids.each_slice(1_000) { |ids| UserAssociatedAccount.where(id: ids).delete_all }

    updates =
      wanted_by_identity.filter_map do |(provider_name, provider_uid), user_id|
        current_id, current_uid = current_by_user[[user_id, provider_name]]
        next if current_id.nil? || current_uid == provider_uid

        users_by_account_id[current_id] = user_id
        { id: current_id, provider_uid: provider_uid }
      end
    result = update_records(updates, "user_associated_account", [:provider_uid])
    @delta_stats[:users][:updated_ids].merge(
      result[:updated_keys].filter_map { |id| users_by_account_id[id.to_i] },
    )
  ensure
    rows&.close
  end

  def import_topics
    puts "", "Importing topics..."

    start_delta_entity(:topics, "topics", :topics, @last_topic_id)
    if delta_import?
      update_delta_topics
    else
      close_existing_topics
    end

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
        archetype:
          (
            if row["private_message"]
              Archetype.private_message
            else
              Archetype.default
            end
          ),
        imported_id: row["id"],
        title: row["title"],
        user_id: user_id_from_imported_id(row["user_id"]),
        created_at: to_datetime(row["created_at"]),
        category_id: category_id,
        closed: to_boolean(row["closed"]),
        archived: to_boolean(row["archived"]),
        views: row["views"],
        subtype: row["subtype"],
        pinned_at: to_datetime(row["pinned_at"]),
        pinned_until: to_datetime(row["pinned_until"]),
        pinned_globally: to_boolean(row["pinned_globally"]),
      }
    end

    topics.close
    finish_delta_entity(:topics, :topics)
  end

  # Under MERGE_IMPORT the imported-id maps are cleared to avoid cross-source
  # collisions, so this pass maps nothing and is a deliberate no-op there.
  def close_existing_topics
    closed_topics = query(<<~SQL)
      SELECT id
      FROM topics
      WHERE closed = 1
      ORDER BY id
    SQL
    mapped_topic_ids = closed_topics.filter_map { |row| topic_id_from_imported_id(row["id"]) }.uniq
    closed_topics.close

    mapped_topic_ids.each_slice(1_000) do |topic_ids|
      Topic.where(id: topic_ids, closed: false).update_all(closed: true)
    end
  end

  def update_delta_topics
    source_columns = table_column_names("topics")
    columns = %i[
      title
      fancy_title
      slug
      user_id
      category_id
      views
      closed
      archived
      pinned_at
      pinned_until
      pinned_globally
      subtype
    ]
    rows = query("SELECT * FROM topics ORDER BY id")
    updates =
      rows.filter_map do |row|
        discourse_id = delta_update_mapping(:topics)[row["id"].to_i]
        next unless discourse_id

        update = { id: discourse_id }
        if row["title"].present?
          update[:title] = row["title"][0...255].scrub.strip
          update[:fancy_title] = (
            if source_columns.include?("fancy_title") && row["fancy_title"].present?
              row["fancy_title"]
            else
              pre_fancy(update[:title])
            end
          )
          update[:slug] = (
            if source_columns.include?("slug") && row["slug"].present?
              row["slug"]
            else
              Slug.for(update[:title])
            end
          )
        end
        update[:user_id] = user_id_from_imported_id(row["user_id"]) if row["user_id"].present?
        if row["category_id"].present?
          update[:category_id] = category_id_from_imported_id(row["category_id"])
        end
        update[:views] = row["views"] if source_columns.include?("views") && !row["views"].nil?
        %i[archived pinned_globally].each do |column|
          if source_columns.include?(column.to_s)
            update[column] = to_nullable_boolean(row[column.to_s])
          end
        end
        update[:closed] = true if source_columns.include?("closed") && to_boolean(row["closed"])
        update[:subtype] = row["subtype"] if source_columns.include?("subtype")
        %i[pinned_at pinned_until].each do |column|
          if source_columns.include?(column.to_s) && row[column.to_s].present?
            update[column] = to_datetime(row[column.to_s])
          end
        end
        update
      end
    result = update_records(updates, "topic", columns)
    record_delta_updates(:topics, result)

    # direct SQL updates bypass the model callbacks that keep search in sync
    Topic
      .unscoped
      .where(id: result[:updated_keys])
      .find_each { |topic| SearchIndexer.index(topic, force: true) }
  ensure
    rows&.close
  end

  def import_topic_custom_fields
    puts "", "Importing topic custom fields..."

    upsert_delta_custom_fields(:topic, :topics) if delta_import?

    topic_custom_fields = query(<<~SQL)
      SELECT *
      FROM topic_custom_fields
      ORDER BY topic_id, name
    SQL

    field_names =
      query("SELECT DISTINCT name FROM topic_custom_fields") { it.map { |row| row["name"] } }
    existing_topic_custom_fields =
      TopicCustomField.where(name: field_names).pluck(:topic_id, :name).to_set

    create_topic_custom_fields(topic_custom_fields) do |row|
      topic_id = topic_id_from_imported_id(row["topic_id"])
      next if topic_id.nil?

      next unless existing_topic_custom_fields.add?([topic_id, row["name"]])

      { topic_id: topic_id, name: row["name"], value: row["value"] }
    end

    topic_custom_fields.close
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

    start_delta_entity(:posts, "posts", :posts, @last_post_id)
    update_delta_posts if delta_import?

    posts = query(<<~SQL)
      SELECT *
      FROM posts
      ORDER BY topic_id, post_number, id
    SQL

    create_posts(posts) do |row|
      next if row["raw"].blank?
      next unless (topic_id = topic_id_from_imported_id(row["topic_id"]))
      next if post_id_from_imported_id(row["id"]).present?

      {
        imported_id: row["id"],
        topic_id: topic_id,
        user_id: user_id_from_imported_id(row["user_id"]),
        created_at: to_datetime(row["created_at"]),
        raw: raw_with_placeholders_interpolated(row["raw"], row),
        like_count: row["like_count"],
        reply_to_post_number:
          (
            if row["reply_to_post_id"]
              post_number_from_imported_id(row["reply_to_post_id"])
            else
              nil
            end
          ),
      }
    end

    posts.close
    finish_delta_entity(:posts, :posts)
  end

  def update_delta_posts
    rows = query("SELECT * FROM posts ORDER BY id")
    updates =
      rows.lazy.filter_map do |row|
        discourse_id = delta_update_mapping(:posts)[row["id"].to_i]
        next unless discourse_id

        update = { id: discourse_id }
        if row["user_id"].present?
          update[:user_id] = user_id_from_imported_id(row["user_id"])
          update[:last_editor_id] = update[:user_id]
        end
        unless row["raw"].nil?
          raw = raw_with_placeholders_interpolated(row["raw"], row)
          if (raw = prepare_delta_post_raw(raw, original_id: row["id"]))
            update[:raw] = raw
            update[:word_count] = raw.scan(/[[:word:]]+/).size
          end
        end
        update
      end
    result = update_records(updates, "post", %i[user_id last_editor_id raw word_count])
    record_delta_updates(:posts, result)

    # cooked content is regenerated by the post-delta rebake; clearing the
    # marker scopes that rebake to the posts this delta touched
    result[:updated_keys].each_slice(10_000) do |ids|
      DB.exec("UPDATE posts SET baked_version = NULL WHERE id IN (#{ids.join(",")})")
    end
  ensure
    rows&.close
  end

  def prepare_delta_post_raw(raw, original_id:)
    raw = raw.scrub.strip.presence || "<Empty imported post>"
    raw = process_raw(raw)
    if @bbcode_to_md
      raw =
        begin
          raw.bbcode_to_md(false, {}, :disable, :quote)
        rescue StandardError
          raw
        end
    end
    raw = normalize_text(raw)

    if raw.bytes.include?(0)
      log_import_issue("raw update skipped (raw contains null bytes)", "post #{original_id}")
      return nil
    end

    raw
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
        if (placeholder = poll_mapping.delete(poll["id"]))
          raw.gsub!(placeholder, poll_bbcode(poll))
        end
      end

      poll_details.close

      # Remove placeholders for polls without options
      poll_mapping.each_value { |placeholder| raw.gsub!(placeholder, "") }
    end

    if (mentions = placeholders&.fetch("mentions", nil))
      mentions.each do |mention|
        name = resolve_mentioned_name(mention)

        unless name
          log_import_issue(
            "unresolved #{mention["type"]} mention",
            "#{mention["placeholder"]} (content #{row["id"]})",
          )
        end
        raw.gsub!(mention["placeholder"], " @#{name} ")
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
            bbcode_parts << (name.presence || username)
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
    return unless defined?(DiscourseEvents::Events)

    starts_at = to_datetime(event["starts_at"])
    ends_at = to_datetime(event["ends_at"])
    status = DiscourseEvents::Events::Event.statuses[event["status"]].to_s
    name =
      if (name = event["name"].presence)
        name.ljust(DiscourseEvents::Events::Event::MIN_NAME_LENGTH, ".").truncate(
          DiscourseEvents::Events::Event::MAX_NAME_LENGTH,
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

    upsert_delta_custom_fields(:post, :posts) if delta_import?

    post_custom_fields = query(<<~SQL)
      SELECT *
      FROM post_custom_fields
      ORDER BY post_id, name
    SQL

    field_names =
      query("SELECT DISTINCT name FROM post_custom_fields") { it.map { |row| row["name"] } }
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
        closed_at: to_datetime(row["close_at"]),
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
      next if option_ids.all? { |oid| poll_option_id_from_original_id(oid).present? }

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
  end

  def import_engagement
    import_likes
    import_reactions
    import_reaction_users
    import_reaction_shadow_likes

    puts "", "Updating engagement statistics..."
    start_time = Time.now
    update_engagement_stats
    puts "  Update took #{(Time.now - start_time).to_i} seconds."
  end

  def update_engagement_stats
    DB.exec(
      <<~SQL,
        WITH post_likes AS (
          SELECT post_actions.post_id,
                 COUNT(*) AS like_count,
                 SUM(
                   CASE
                     WHEN users.moderator OR users.admin THEN :staff_like_weight
                     ELSE 1
                   END
                 ) AS like_score
            FROM post_actions
                 LEFT JOIN users ON users.id = post_actions.user_id
           WHERE post_actions.post_action_type_id = :like_type_id
             AND post_actions.deleted_at IS NULL
           GROUP BY post_actions.post_id
        )
        UPDATE posts
           SET like_count = post_likes.like_count,
               like_score = post_likes.like_score
          FROM post_likes
         WHERE posts.id = post_likes.post_id
      SQL
      like_type_id: PostActionType::LIKE_POST_ACTION_ID,
      staff_like_weight: SiteSetting.staff_like_weight,
    )

    DB.exec(<<~SQL, whisper_post_type: Post.types[:whisper])
      WITH topic_likes AS (
        SELECT topic_id, SUM(like_count) AS like_count
          FROM posts
         WHERE deleted_at IS NULL
           AND post_type <> :whisper_post_type
         GROUP BY topic_id
      )
      UPDATE topics
         SET like_count = topic_likes.like_count
        FROM topic_likes
       WHERE topics.id = topic_likes.topic_id
         AND topics.like_count <> topic_likes.like_count
    SQL

    return unless defined?(DiscourseReactions)

    DB.exec(<<~SQL)
      UPDATE discourse_reactions_reactions
         SET reaction_users_count = (
           SELECT COUNT(*)
             FROM discourse_reactions_reaction_users
            WHERE discourse_reactions_reaction_users.reaction_id = discourse_reactions_reactions.id
         )
    SQL
  end

  def import_topic_users
    puts "", "Importing topic users..."

    topic_users = query(<<~SQL)
      SELECT *
        FROM topic_users
       ORDER BY user_id, topic_id
    SQL

    existing_topic_users = TopicUser.pluck(:topic_id, :user_id).to_set

    create_topic_users(topic_users) do |row|
      user_id = user_id_from_imported_id(row["user_id"])
      topic_id = topic_id_from_imported_id(row["topic_id"])
      next unless user_id && topic_id
      next if existing_topic_users.include?([topic_id, user_id])

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

    DB.exec(<<~SQL, notification_level: NotificationLevels.topic_levels[:watching])
      WITH
        latest_posts AS (
                          SELECT p.topic_id, MAX(p.post_number) AS number
                            FROM posts p
                          WHERE p.deleted_at IS NULL
                            AND NOT p.hidden
                            AND p.user_id > 0
                          GROUP BY p.topic_id
                        )
      UPDATE topic_users tu
        SET last_read_post_number = latest_posts.number
      FROM latest_posts
           JOIN topics t ON t.id = latest_posts.topic_id
      WHERE tu.topic_id = latest_posts.topic_id
        AND tu.notification_level = :notification_level
        AND tu.last_read_post_number IS NULL
        AND t.deleted_at IS NULL
        AND t.visible
    SQL

    puts "  Updated topic users in #{(Time.now - start_time).to_i} seconds."
  end

  def import_bookmarks
    unless @source_db.get_first_value(
             "SELECT 1 FROM sqlite_master WHERE type='table' AND name='bookmarks'",
           )
      return
    end

    puts "", "Importing bookmarks..."

    bookmarks = query(<<~SQL)
      SELECT id, user_id, bookmarkable_id, bookmarkable_type, name,
             reminder_at, reminder_set_at, reminder_last_sent_at,
             auto_delete_preference, pinned, created_at, updated_at
        FROM bookmarks
       ORDER BY user_id, bookmarkable_id
    SQL

    existing_bookmarks = Bookmark.pluck(:user_id, :bookmarkable_type, :bookmarkable_id).to_set

    create_bookmarks(bookmarks) do |row|
      user_id = user_id_from_imported_id(row["user_id"])
      next unless user_id

      bookmarkable_type = row["bookmarkable_type"].to_s
      bookmarkable_id = row["bookmarkable_id"]

      if bookmarkable_type == "Topic"
        topic_id = topic_id_from_imported_id(bookmarkable_id)
        next unless topic_id
        next unless existing_bookmarks.add?([user_id, bookmarkable_type, topic_id])

        {
          user_id: user_id,
          bookmarkable_id: topic_id,
          bookmarkable_type: bookmarkable_type,
          name: row["name"],
          reminder_at: to_datetime(row["reminder_at"]),
          reminder_set_at: to_datetime(row["reminder_set_at"]),
          reminder_last_sent_at: to_datetime(row["reminder_last_sent_at"]),
          auto_delete_preference: row["auto_delete_preference"]&.to_i,
          pinned: row["pinned"].present? ? to_boolean(row["pinned"]) : false,
          created_at: to_datetime(row["created_at"]),
          updated_at: to_datetime(row["updated_at"]),
        }
      elsif bookmarkable_type == "Post"
        post_id = post_id_from_imported_id(bookmarkable_id)
        next unless post_id
        next unless existing_bookmarks.add?([user_id, bookmarkable_type, post_id])

        {
          user_id: user_id,
          bookmarkable_id: post_id,
          bookmarkable_type: bookmarkable_type,
          name: row["name"],
          reminder_at: to_datetime(row["reminder_at"]),
          reminder_set_at: to_datetime(row["reminder_set_at"]),
          reminder_last_sent_at: to_datetime(row["reminder_last_sent_at"]),
          auto_delete_preference: row["auto_delete_preference"]&.to_i,
          pinned: row["pinned"].present? ? to_boolean(row["pinned"]) : false,
          created_at: to_datetime(row["created_at"]),
          updated_at: to_datetime(row["updated_at"]),
        }
      else
        next
      end
    end

    bookmarks.close

    puts "  Updating topic_users.bookmarked from bookmarks..."
    DB.exec(<<~SQL)
      INSERT INTO topic_users (user_id, topic_id, bookmarked)
      SELECT b.user_id, b.bookmarkable_id, TRUE
        FROM bookmarks b
       WHERE b.bookmarkable_type = 'Topic'
      ON CONFLICT (user_id, topic_id) DO UPDATE SET bookmarked = TRUE
    SQL
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

    existing_user_ids = MutedUser.pluck(:user_id, :muted_user_id).to_set

    create_muted_users(muted_users) do |row|
      user_id = user_id_from_imported_id(row["user_id"])
      muted_user_id = user_id_from_imported_id(row["muted_user_id"])
      next unless user_id && muted_user_id
      next if existing_user_ids.include?([user_id, muted_user_id])

      { user_id: user_id, muted_user_id: muted_user_id }
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

  def import_user_notes
    puts "", "Importing user notes..."

    unless defined?(DiscourseUserNotes)
      puts "  Skipping import of user notes because the plugin is not installed."
      return
    end

    user_notes = query(<<~SQL)
      SELECT un.user_id,
             JSON_GROUP_ARRAY(JSON_OBJECT('raw', un.raw, 'created_by', un.created_by_user_id,
                                          'created_at', un.created_at)) AS note_json_text
        FROM user_notes un
             JOIN users u ON u.id = un.user_id
       WHERE u.anonymized IS NOT TRUE
       GROUP BY un.user_id
       ORDER BY un.user_id, un.id
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

    unless defined?(DiscourseUserNotes)
      puts "  Skipping import of user notes because the plugin is not installed."
      return
    end

    user_note_counts = query(<<~SQL)
      SELECT un.user_id, COUNT(*) AS count
        FROM user_notes un
             JOIN users u ON u.id = un.user_id
       WHERE u.anonymized IS NOT TRUE
       GROUP BY un.user_id
       ORDER BY un.user_id
    SQL

    existing_user_ids = UserCustomField.where(name: "user_notes_count").pluck(:user_id).to_set

    create_user_custom_fields(user_note_counts) do |row|
      user_id = user_id_from_imported_id(row["user_id"])
      next if !user_id || existing_user_ids.include?(user_id)

      { user_id: user_id, name: "user_notes_count", value: row["count"].to_s }
    end

    user_note_counts.close
  end

  def import_user_custom_fields
    puts "", "Importing user custom fields..."

    upsert_delta_custom_fields(:user, :users, anonymized_filter: true) if delta_import?

    rows = query(<<~SQL)
      SELECT ucf.user_id, ucf.name, ucf.value, ucf.created_at
        FROM user_custom_fields ucf
             JOIN users u ON u.id = ucf.user_id
       WHERE u.anonymized IS NOT TRUE
    SQL

    existing_names = query(<<~SQL) { |rs| rs.map { |r| r["name"] } }
        SELECT DISTINCT ucf.name
          FROM user_custom_fields ucf
               JOIN users u ON u.id = ucf.user_id
         WHERE u.anonymized IS NOT TRUE
      SQL

    return if existing_names.empty?

    existing = UserCustomField.where(name: existing_names).pluck(:user_id, :name).to_set

    create_user_custom_fields(rows) do |row|
      user_id = user_id_from_imported_id(row["user_id"])
      next if !user_id
      next if existing.include?([user_id, row["name"]])

      {
        user_id: user_id,
        name: row["name"],
        value: row["value"],
        created_at: to_datetime(row["created_at"]),
      }
    end

    rows.close

    puts "", "Cooking signature_cooked from signature_raw..."

    sig_rows = query(<<~SQL)
      SELECT ucf.user_id, ucf.value
        FROM user_custom_fields ucf
             JOIN users u ON u.id = ucf.user_id
       WHERE ucf.name = 'signature_raw'
         AND u.anonymized IS NOT TRUE
    SQL

    cooked_existing = UserCustomField.where(name: "signature_cooked").pluck(:user_id).to_set

    create_user_custom_fields(sig_rows) do |row|
      user_id = user_id_from_imported_id(row["user_id"])
      next if !user_id || cooked_existing.include?(user_id)
      raw_sig = row["value"].to_s.strip
      next if raw_sig.empty?
      { user_id: user_id, name: "signature_cooked", value: PrettyText.cook(raw_sig) }
    end
    sig_rows.close
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

    DB.exec(<<~SQL) unless delta_import?
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

    update_delta_user_avatars if delta_import?

    avatars = query(<<~SQL)
      SELECT id, avatar_upload_id
        FROM users
       WHERE avatar_upload_id IS NOT NULL
         AND anonymized IS NOT TRUE
       ORDER BY id
    SQL

    existing_user_ids = UserAvatar.pluck(:user_id).to_set

    create_user_avatars(avatars) do |row|
      user_id = user_id_from_imported_id(row["id"])
      upload_id = upload_id_from_original_id(row["avatar_upload_id"])
      next if delta_deduplicated_source_id?(:users, row["id"])
      next if !upload_id || !user_id || existing_user_ids.include?(user_id)

      { user_id: user_id, custom_upload_id: upload_id }
    end

    avatars.close
  end

  def update_delta_user_avatars
    existing_avatars =
      UserAvatar.where(user_id: delta_update_mapping(:users).values).index_by(&:user_id)
    rows = query(<<~SQL)
      SELECT id, avatar_upload_id
        FROM users
       WHERE avatar_upload_id IS NOT NULL
         AND anonymized IS NOT TRUE
       ORDER BY id
    SQL
    updates = []
    rows.each do |row|
      user_id = delta_update_mapping(:users)[row["id"].to_i]
      upload_id = upload_id_from_original_id(row["avatar_upload_id"])
      avatar = existing_avatars[user_id]
      next unless user_id && upload_id && avatar

      updates << { id: avatar.id, user_id: user_id, custom_upload_id: upload_id }
    end
    result = update_records(updates, "user_avatar", [:custom_upload_id])
    users_by_avatar_id = updates.to_h { |update| [update[:id], update[:user_id]] }
    @delta_stats[:users][:updated_ids].merge(
      result[:updated_keys].filter_map { |id| users_by_avatar_id[id.to_i] },
    )

    updates.each do |update|
      UploadReference.ensure_exist!(
        upload_ids: [update[:custom_upload_id]],
        target_type: "UserAvatar",
        target_id: update[:id],
      )
    end
  ensure
    rows&.close
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

    reconcile_delta_post_upload_references if delta_import? && type == "posts"

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

  def reconcile_delta_post_upload_references
    rows = query("SELECT id, upload_ids FROM posts WHERE upload_ids IS NOT NULL ORDER BY id")
    rows.each do |row|
      post_id = post_id_from_imported_id(row["id"])
      next unless post_id

      original_upload_ids = JSON.parse(row["upload_ids"])
      upload_ids =
        original_upload_ids.filter_map { |original_id| upload_id_from_original_id(original_id) }
      if upload_ids.size != original_upload_ids.size
        log_import_issue(
          "post upload reconciliation skipped (unmapped uploads)",
          "post #{row["id"]}",
        )
        next
      end
      existing_ids =
        UploadReference.where(target_type: "Post", target_id: post_id).pluck(:upload_id).sort
      next if existing_ids == upload_ids.uniq.sort

      UploadReference.ensure_exist!(upload_ids: upload_ids, target_type: "Post", target_id: post_id)
      if delta_update_mapping(:posts).key?(row["id"].to_i)
        @delta_stats[:posts][:updated_ids] << post_id
      end
    end
  ensure
    rows&.close
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

    if delta_import?
      avatar_predicate = "u.uploaded_avatar_id IS DISTINCT FROM ua.custom_upload_id"
      mapping_predicate = <<~SQL.squish
        AND EXISTS (
          SELECT 1
            FROM user_custom_fields mapping
           WHERE mapping.user_id = u.id
             AND mapping.name = 'import_id'
             AND mapping.value ~ '^[0-9]+$'
        )
      SQL
    else
      avatar_predicate = "u.uploaded_avatar_id IS NULL"
      mapping_predicate = ""
    end
    DB.exec(<<~SQL)
      UPDATE users u
         SET uploaded_avatar_id = ua.custom_upload_id
        FROM user_avatars ua
       WHERE #{avatar_predicate}
         AND u.id = ua.user_id
         AND ua.custom_upload_id IS NOT NULL
         #{mapping_predicate}
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
      description = row["description"].presence&.truncate(1000)
      tag =
        Tag
          .where("LOWER(name) = ?", cleaned_tag_name.downcase)
          .first_or_create!(name: cleaned_tag_name) { |t| t.description = description }
      if description && tag.description != description
        tag.update_columns(description: sanitize_field(description))
      end
      @tag_mapping[row["id"]] = tag.id

      intermediate_group_ids = []
      if row["tag_group_ids"] && !row["tag_group_ids"].empty?
        intermediate_group_ids = JSON.parse(row["tag_group_ids"])
      elsif row["tag_group_id"] && !row["tag_group_id"].empty?
        # Support old single tag_group_id
        intermediate_group_ids = [row["tag_group_id"]]
      end

      if intermediate_group_ids.any?
        intermediate_group_ids.each do |intermediate_group_id|
          intermediate_group_id = intermediate_group_id.to_i
          discourse_tag_group_id = @tag_group_mapping[intermediate_group_id]

          if discourse_tag_group_id
            TagGroupMembership.find_or_create_by!(
              tag_id: tag.id,
              tag_group_id: discourse_tag_group_id,
            )
          else
            log_import_issue(
              "tag group mapping missing",
              "intermediate tag group #{intermediate_group_id} for tag '#{tag.name}'",
            )
          end
        end
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

  def import_post_voting_votes
    puts "", "Importing votes for posts..."

    unless defined?(PostVoting)
      puts "  Skipping import of votes for posts because the plugin is not installed."
      return
    end

    votes = query(<<~SQL)
      SELECT *
        FROM post_voting_votes
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

  def import_topic_voting_votes
    unless defined?(DiscourseTopicVoting)
      puts "", "Skipping topic voting votes, because the topic voting plugin is not installed."
      return
    end

    puts "", "Importing votes for topics..."

    topic_votes = query(<<~SQL)
      SELECT *
      FROM topic_voting_votes
    SQL

    existing_topic_votes = DiscourseTopicVoting::Vote.pluck(:topic_id, :user_id).to_set

    create_topic_voting_votes(topic_votes) do |row|
      topic_id = topic_id_from_imported_id(row["topic_id"])
      user_id = user_id_from_imported_id(row["user_id"])

      next unless topic_id && user_id
      next unless existing_topic_votes.add?([topic_id, user_id])

      {
        topic_id: topic_id,
        user_id: user_id,
        archive: to_boolean(row["archive"]),
        created_at: to_datetime(row["created_at"]),
        updated_at: to_datetime(row["updated_at"]),
      }
    end

    topic_votes.close

    puts "", "Updating vote counts of topics..."

    start_time = Time.now

    DB.exec(<<~SQL)
        WITH
          votes AS (
                     SELECT topic_id, COUNT(*) AS votes_count
                     FROM topic_voting_votes
                     GROUP BY topic_id
                   )
      UPDATE topic_voting_topic_vote_count
         SET votes_count = votes.votes_count
        FROM votes
       WHERE votes.topic_id = topic_voting_topic_vote_count.topic_id
         AND votes.votes_count <> topic_voting_topic_vote_count.votes_count
    SQL

    DB.exec(<<~SQL)
        WITH
          missing_votes AS (
                             SELECT v.topic_id, COUNT(*) AS votes_count
                               FROM topic_voting_votes v
                              WHERE NOT EXISTS (
                                                 SELECT 1
                                                 FROM topic_voting_topic_vote_count c
                                                 WHERE v.topic_id = c.topic_id
                                               )
                              GROUP BY topic_id
                           )
      INSERT
        INTO topic_voting_topic_vote_count (votes_count, topic_id, created_at, updated_at)
      SELECT votes_count, topic_id, NOW(), NOW()
        FROM missing_votes
          ON CONFLICT DO NOTHING
    SQL

    puts "  Update took #{(Time.now - start_time).to_i} seconds."
  end

  def import_answers
    unless defined?(DiscourseSolved)
      puts "  Skipping import of solved topics"
      return
    end

    puts "", "Importing solutions into discourse_solved_solved_topics..."

    solutions = query(<<~SQL)
      SELECT *
        FROM solutions
       ORDER BY topic_id
    SQL

    existing_solved_topics = DiscourseSolved::SolvedTopic.pluck(:topic_id).to_set
    inserted_topic_ids = []

    create_solved_topic(solutions) do |row|
      topic_id = topic_id_from_imported_id(row["topic_id"])
      next unless topic_id && existing_solved_topics.add?(topic_id)

      inserted_topic_ids << topic_id
      { topic_id:, created_at: to_datetime(row["created_at"]) }
    end

    puts "", "Importing solutions into discourse_solved_topic_answers..."

    solved_topic_id_by_topic_id =
      DiscourseSolved::SolvedTopic.where(topic_id: inserted_topic_ids).pluck(:topic_id, :id).to_h

    solutions.reset

    create_topic_answers(solutions) do |row|
      topic_id = topic_id_from_imported_id(row["topic_id"])
      solved_topic_id = solved_topic_id_by_topic_id[topic_id]
      next unless solved_topic_id

      post_id = post_id_from_imported_id(row["post_id"])
      next unless post_id

      {
        solved_topic_id:,
        answer_post_id: post_id,
        accepter_user_id: user_id_from_imported_id(row["acting_user_id"]),
        created_at: to_datetime(row["created_at"]),
      }
    end

    puts "", "Importing solutions into user actions..."

    solutions.reset

    action_type = UserAction::SOLVED
    existing_actions = UserAction.where(action_type: action_type).pluck(:target_post_id).to_set

    create_user_actions(solutions) do |row|
      post_id = post_id_from_imported_id(row["post_id"])
      next unless post_id && existing_actions.add?(post_id)

      topic_id = topic_id_from_imported_id(row["topic_id"])
      user_id = user_id_from_imported_id(row["user_id"])
      next unless topic_id && user_id

      acting_user_id =
        (
          if row["acting_user_id"]
            user_id_from_imported_id(row["acting_user_id"])
          else
            nil
          end
        )

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

    unless defined?(DiscourseGamification)
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

    unless defined?(DiscourseEvents::Events)
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
    public_group_invitees = "{#{DiscourseEvents::Events::Event::PUBLIC_GROUP}}"
    standalone_invitees = "{}"

    existing_events = DiscourseEvents::Events::Event.pluck(:id).to_set

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
            if row["status"] == DiscourseEvents::Events::Event.statuses[:public]
              public_group_invitees
            else
              standalone_invitees
            end
          ),
      }
    end

    puts "", "Importing event dates..."

    post_events.reset
    existing_events = DiscourseEvents::Events::EventDate.pluck(:event_id).to_set

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
    field_name = DiscourseEvents::Events::TOPIC_POST_EVENT_STARTS_AT
    existing_fields = TopicCustomField.where(name: field_name).pluck(:topic_id).to_set

    create_topic_custom_fields(post_events) do |row|
      date = to_datetime(row["starts_at"])
      next unless date

      topic_id = topic_id_from_imported_post_id(row["post_id"])
      next if !topic_id || existing_fields.include?(topic_id)

      { topic_id: topic_id, name: field_name, value: date.utc.strftime("%Y-%m-%d %H:%M:%S") }
    end

    post_events.reset
    field_name = DiscourseEvents::Events::TOPIC_POST_EVENT_ENDS_AT
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

    existing_tag_users = TagUser.pluck(:tag_id, :user_id).to_set

    create_tag_users(tag_users) do |row|
      tag_id = @tag_mapping[row["tag_id"]]
      user_id = user_id_from_imported_id(row["user_id"])

      next unless tag_id && user_id
      next if existing_tag_users.include?([tag_id, user_id])

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
          (
            if row["image_upload_id"]
              upload_id_from_original_id(row["image_upload_id"])
            else
              nil
            end
          ),
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

  def import_anniversary_user_badges
    unless SiteSetting.enable_badges?
      puts "", "Skipping anniversary user badges because badges are not enabled."
      return
    end

    puts "", "Importing anniversary user badges..."

    start_time = Time.now

    DB.exec(<<~SQL)
      WITH
        eligible_users AS (
                            SELECT u.id, u.created_at
                            FROM users u
                            WHERE u.active
                              AND NOT u.staged
                              AND u.id > 0
                              AND (u.silenced_till IS NULL OR u.silenced_till < CURRENT_TIMESTAMP)
                              AND (u.suspended_till IS NULL OR u.suspended_till < CURRENT_TIMESTAMP)
                              AND NOT EXISTS (SELECT 1 FROM anonymous_users AS au WHERE au.user_id = u.id)
                          ),
        anniversary_dates AS ( -- Series of anniversary dates starting from the user's created_at + 1 year up to the current year
                               SELECT
                                 eu.id AS user_id,
                                 (
                                   eu.created_at +
                                   ((year_num - EXTRACT(YEAR FROM eu.created_at)) || ' years')::interval
                                 )::timestamp AS anniversary_date
                               FROM eligible_users eu,
                                    generate_series(
                                      EXTRACT(YEAR FROM eu.created_at)::int + 1,
                                      EXTRACT(YEAR FROM CURRENT_TIMESTAMP)::int
                                    ) AS year_num
                                WHERE
                                  (
                                    eu.created_at +
                                    ((year_num - EXTRACT(YEAR FROM eu.created_at)) || ' years')::interval
                                  ) < CURRENT_TIMESTAMP
                             ),
        existing_max_seq AS (
                              SELECT user_id, COALESCE(MAX(seq), -1) AS max_seq
                              FROM user_badges
                              WHERE badge_id = #{Badge::Anniversary}
                              GROUP BY user_id
                            )
      INSERT INTO user_badges (granted_at, created_at, granted_by_id, user_id, badge_id, seq)
      SELECT a.anniversary_date,
             CURRENT_TIMESTAMP,
             #{Discourse.system_user.id},
             a.user_id,
             #{Badge::Anniversary},
             COALESCE(ems.max_seq, -1) + ROW_NUMBER() OVER (PARTITION BY a.user_id ORDER BY a.anniversary_date) AS seq
      FROM anniversary_dates a
           JOIN eligible_users u ON a.user_id = u.id
           JOIN posts AS p ON p.user_id = u.id
           JOIN topics AS t ON p.topic_id = t.id
           LEFT JOIN existing_max_seq ems ON ems.user_id = a.user_id
      WHERE p.deleted_at IS NULL
        AND NOT p.hidden
        AND p.created_at BETWEEN a.anniversary_date - '1 year'::interval AND a.anniversary_date
        AND t.visible
        AND t.archetype <> 'private_message'
        AND t.deleted_at IS NULL
        AND NOT EXISTS (
            SELECT 1
            FROM user_badges AS ub
            WHERE ub.user_id = u.id
            AND ub.badge_id = #{Badge::Anniversary}
            AND ub.granted_at BETWEEN a.anniversary_date - '1 year'::interval AND a.anniversary_date
        )
      GROUP BY a.user_id, a.anniversary_date, ems.max_seq
      ON CONFLICT DO NOTHING
    SQL

    UserBadge.update_featured_ranks!

    puts "  Anniversary user badges imported in #{(Time.now - start_time).to_i} seconds."
  end

  def update_badge_grant_counts
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

      next if chat_thread_id_from_original_id(row["id"]).present?
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

      next if chat_message_id_from_original_id(row["id"]).present?
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

  def import_reaction_users
    unless defined?(DiscourseReactions)
      puts "",
           "Skipping reaction users import, because the Discourse Reactions plugin is not installed."
      return
    end

    puts "", "Importing reaction users..."

    reaction_users = query(<<~SQL)
      SELECT *
      FROM discourse_reactions_reaction_users
      ORDER BY post_id, user_id
    SQL

    existing_reaction_users =
      DiscourseReactions::ReactionUser.pluck(:reaction_id, :user_id, :post_id).to_set

    create_reaction_users(reaction_users) do |row|
      next if row["reaction_id"].blank?

      user_id = user_id_from_imported_id(row["user_id"])
      post_id = post_id_from_imported_id(row["post_id"])
      reaction_id = discourse_reaction_id_from_original_id(row["reaction_id"])

      next if post_id.blank? || user_id.blank? || reaction_id.blank?
      next unless existing_reaction_users.add?([reaction_id, user_id, post_id])

      {
        reaction_id:,
        user_id:,
        created_at: to_datetime(row["created_at"]),
        updated_at: to_datetime(row["updated_at"]),
        post_id:,
      }
    end

    reaction_users.close
  end

  def import_reactions
    unless defined?(DiscourseReactions)
      puts "", "Skipping reactions import, because the Discourse Reactions plugin is not installed."
      return
    end

    puts "", "Importing reactions..."

    reactions = query(<<~SQL)
      SELECT r.*,
            COALESCE((SELECT COUNT(*)
                      FROM discourse_reactions_reaction_users ru
                      WHERE ru.reaction_id = r.id), 0) as count
      FROM discourse_reactions_reactions r
      ORDER BY r.post_id, r.reaction_value
    SQL

    reaction_type_id = DiscourseReactions::Reaction.reaction_types["emoji"]
    existing_reactions = DiscourseReactions::Reaction.pluck(:post_id, :reaction_value).to_set

    create_reactions(reactions) do |row|
      next if row["id"].blank?

      post_id = post_id_from_imported_id(row["post_id"])

      next if post_id.blank? || row["reaction_value"].blank?
      next unless existing_reactions.add?([post_id, row["reaction_value"]])

      {
        original_id: row["id"],
        post_id: post_id,
        reaction_type: reaction_type_id,
        reaction_value: row["reaction_value"],
        reaction_users_count: row["count"],
        created_at: to_datetime(row["created_at"]),
        updated_at: to_datetime(row["updated_at"]),
      }
    end

    reactions.close
  end

  def import_reaction_shadow_likes
    unless defined?(DiscourseReactions)
      puts "",
           "Skipping reaction shadow likes import, because the Discourse Reactions plugin is not installed."
      return
    end

    puts "", "Importing reaction shadow likes..."

    reactions = query(<<~SQL)
      SELECT u.post_id, u.user_id, r.reaction_value, u.created_at
        FROM discourse_reactions_reactions r
             JOIN discourse_reactions_reaction_users u ON r.id = u.reaction_id
       ORDER BY u.post_id, u.user_id
    SQL

    post_action_type_id = PostActionType.types[:like]
    existing_likes =
      PostAction.where(post_action_type_id: post_action_type_id).pluck(:post_id, :user_id).to_set

    create_post_actions(reactions) do |row|
      next if reaction_excluded_from_like?(row["reaction_value"])

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

    reactions.close
  end

  def reaction_excluded_from_like?(reaction_value)
    DiscourseReactions::Reaction.reactions_excluded_from_like.include?(reaction_value)
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

  def table_column_names(table_name, db: @source_db)
    @table_column_names ||= {}
    @table_column_names[[db.object_id, table_name]] ||= query(
      "PRAGMA table_info(#{table_name})",
      db:,
    ) { |rows| rows.map { |row| row["name"] }.to_set }
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

  def to_nullable_boolean(value)
    value.nil? ? nil : to_boolean(value)
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

BulkImport::Generic.new(ARGV[0], ARGV[1]).start if $PROGRAM_NAME == __FILE__

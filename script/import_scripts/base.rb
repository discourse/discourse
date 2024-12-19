# frozen_string_literal: true

if ARGV.include?("bbcode-to-md")
  # Replace (most) bbcode with markdown before creating posts.
  # This will dramatically clean up the final posts in Discourse.
  #
  # In a temp dir:
  #
  # git clone https://github.com/nlalonde/ruby-bbcode-to-md.git
  # cd ruby-bbcode-to-md
  # gem build ruby-bbcode-to-md.gemspec
  # gem install ruby-bbcode-to-md-*.gem
  require "ruby-bbcode-to-md"
end

require_relative "../../config/environment"
require_relative "base/lookup_container"
require_relative "base/uploader"

module ImportScripts
end

class ImportScripts::Base
  def initialize
    preload_i18n

    @lookup = ImportScripts::LookupContainer.new
    @uploader = ImportScripts::Uploader.new

    @bbcode_to_md = true if use_bbcode_to_md?
    @site_settings_during_import = {}
    @old_site_settings = {}
    @start_times = { import: Time.now }
    @skip_updates = false
    @next_category_color_index = {}
  end

  def preload_i18n
    I18n.t("test")
    ActiveSupport::Inflector.transliterate("test")
  end

  def perform
    Rails.logger.level = 3 # :error, so that we don't create log files that are many GB

    change_site_settings
    execute

    puts ""

    unless @skip_updates
      update_topic_status
      update_bumped_at
      update_last_posted_at
      update_last_seen_at
      update_user_stats
      update_topic_users
      update_post_timings
      update_feature_topic_users
      update_category_featured_topics
      reset_topic_counters
    end

    elapsed = Time.now - @start_times[:import]
    puts "", "", "Done (%02dh %02dmin %02dsec)" % [elapsed / 3600, elapsed / 60 % 60, elapsed % 60]
  ensure
    reset_site_settings
  end

  def get_site_settings_for_import
    {
      blocked_email_domains: "",
      min_topic_title_length: 1,
      min_post_length: 1,
      min_first_post_length: 1,
      min_personal_message_post_length: 1,
      min_personal_message_title_length: 1,
      allow_duplicate_topic_titles: true,
      allow_duplicate_topic_titles_category: false,
      disable_emails: "yes",
      max_attachment_size_kb: 102_400,
      max_image_size_kb: 102_400,
      authorized_extensions: "*",
      clean_up_inactive_users_after_days: 0,
      clean_up_unused_staged_users_after_days: 0,
      clean_up_uploads: false,
      clean_orphan_uploads_grace_period_hours: 168,
    }
  end

  def change_site_settings
    if SiteSetting.bootstrap_mode_enabled
      SiteSetting.default_trust_level = TrustLevel[0] if SiteSetting.default_trust_level ==
        TrustLevel[1]
      SiteSetting.default_email_digest_frequency =
        10_080 if SiteSetting.default_email_digest_frequency == 1440
      SiteSetting.bootstrap_mode_enabled = false
    end

    @site_settings_during_import = get_site_settings_for_import

    @site_settings_during_import.each do |key, value|
      @old_site_settings[key] = SiteSetting.get(key)
      SiteSetting.set(key, value)
    end

    # Some changes that should not be rolled back after the script is done
    if SiteSetting.purge_unactivated_users_grace_period_days > 0
      SiteSetting.purge_unactivated_users_grace_period_days = 60
    end
    SiteSetting.purge_deleted_uploads_grace_period_days = 90

    RateLimiter.disable
  end

  def reset_site_settings
    @old_site_settings.each do |key, value|
      current_value = SiteSetting.get(key)
      SiteSetting.set(key, value) if current_value == @site_settings_during_import[key]
    end

    RateLimiter.enable
  end

  def use_bbcode_to_md?
    ARGV.include?("bbcode-to-md")
  end

  # Implementation will do most of its work in its execute method.
  # It will need to call create_users, create_categories, and create_posts.
  def execute
    raise NotImplementedError
  end

  %i[
    add_category
    add_group
    add_post
    add_topic
    add_user
    category_id_from_imported_category_id
    find_group_by_import_id
    find_user_by_import_id
    group_id_from_imported_group_id
    post_already_imported?
    post_id_from_imported_post_id
    topic_lookup_from_imported_post_id
    user_already_imported?
    user_id_from_imported_user_id
  ].each { |method_name| delegate method_name, to: :@lookup }

  def create_admin(opts = {})
    admin = User.new
    admin.email = opts[:email] || "sam.saffron@gmail.com"
    admin.username = opts[:username] || "sam"
    admin.password = SecureRandom.uuid
    admin.save!
    admin.grant_admin!
    admin.change_trust_level!(TrustLevel[4])
    admin.email_tokens.update_all(confirmed: true)
    admin
  end

  def created_group(group)
    # override if needed
  end

  # Iterate through a list of groups to be imported.
  # Takes a collection and yields to the block for each element.
  # Block should return a hash with the attributes for each element.
  # Required fields are :id and :name, where :id is the id of the
  # group in the original datasource. The given id will not be used
  # to create the Discourse group record.
  def create_groups(results, opts = {})
    created = 0
    skipped = 0
    failed = 0
    total = opts[:total] || results.count

    results.each do |result|
      g = yield(result)

      if g.nil? || group_id_from_imported_group_id(g[:id])
        skipped += 1
      else
        new_group = create_group(g, g[:id])
        created_group(new_group)

        if new_group.valid?
          add_group(g[:id].to_s, new_group)
          created += 1
        else
          failed += 1
          puts "Failed to create group id #{g[:id]} #{new_group.name}: #{new_group.errors.full_messages}"
        end
      end

      print_status(
        created + skipped + failed + (opts[:offset] || 0),
        total,
        get_start_time("groups"),
      )
    end

    [created, skipped]
  end

  def create_group(opts, import_id)
    opts = opts.dup.tap { |o| o.delete(:id) }

    import_name = opts[:name].presence || opts[:full_name]
    opts[:name] = UserNameSuggester.suggest(import_name)

    existing = Group.find_by(name: opts[:name])
    return existing if existing && existing.custom_fields["import_id"].to_s == import_id.to_s

    g = existing || Group.new(opts)
    g.custom_fields["import_id"] = import_id
    g.custom_fields["import_name"] = import_name

    g.tap(&:save)
  end

  def all_records_exist?(type, import_ids)
    return false if import_ids.empty?

    ActiveRecord::Base.transaction do
      begin
        connection = ActiveRecord::Base.connection.raw_connection
        connection.exec("CREATE TEMP TABLE import_ids(val text PRIMARY KEY)")

        import_id_clause =
          import_ids.map { |id| "('#{PG::Connection.escape_string(id.to_s)}')" }.join(",")

        connection.exec("INSERT INTO import_ids VALUES #{import_id_clause}")

        existing = "#{type.to_s.classify}CustomField".constantize
        existing = existing.where(name: "import_id").joins("JOIN import_ids ON val = value").count

        if existing == import_ids.length
          puts "Skipping #{import_ids.length} already imported #{type}"
          true
        end
      ensure
        connection.exec("DROP TABLE import_ids") unless connection.nil?
      end
    end
  end

  def created_user(user)
    # override if needed
  end

  # Iterate through a list of user records to be imported.
  # Takes a collection, and yields to the block for each element.
  # Block should return a hash with the attributes for the User model.
  # Required fields are :id and :email, where :id is the id of the
  # user in the original datasource. The given id will not be used to
  # create the Discourse user record.
  def create_users(results, opts = {})
    created = 0
    skipped = 0
    failed = 0
    total = opts[:total] || results.count

    results.each do |result|
      u = yield(result)

      # block returns nil to skip a user
      if u.nil?
        skipped += 1
      else
        import_id = u[:id]

        if user_id_from_imported_user_id(import_id)
          skipped += 1
        else
          new_user = create_user(u, import_id)
          created_user(new_user)

          if new_user && new_user.valid? && new_user.user_profile && new_user.user_profile.valid?
            add_user(import_id.to_s, new_user)
            created += 1
          else
            failed += 1
            puts "Failed to create user id: #{import_id}, username: #{new_user.try(:username)}, email: #{new_user.try(:email)}"
            if new_user.try(:errors)
              puts "user errors: #{new_user.errors.full_messages}"
              if new_user.try(:user_profile).try(:errors)
                puts "user_profile errors: #{new_user.user_profile.errors.full_messages}"
              end
            end
          end
        end
      end

      print_status(
        created + skipped + failed + (opts[:offset] || 0),
        total,
        get_start_time("users"),
      )
    end

    [created, skipped]
  end

  def create_user(opts, import_id)
    original_opts = opts.dup
    opts.delete(:id)
    merge = opts.delete(:merge)
    post_create_action = opts.delete(:post_create_action)

    existing = find_existing_user(opts[:email], opts[:username])
    if existing && (merge || existing.custom_fields["import_id"].to_s == import_id.to_s)
      return existing
    end

    bio_raw = opts.delete(:bio_raw)
    website = opts.delete(:website)
    location = opts.delete(:location)
    avatar_url = opts.delete(:avatar_url)

    original_username = opts[:username]
    original_name = opts[:name]
    original_email = opts[:email] = opts[:email].downcase

    if !UsernameValidator.new(opts[:username]).valid_format? ||
         !User.username_available?(opts[:username])
      opts[:username] = UserNameSuggester.suggest(
        opts[:username].presence || opts[:name].presence || opts[:email],
      )
    end

    if !EmailAddressValidator.valid_value?(opts[:email])
      opts[:email] = fake_email
      puts "Invalid email '#{original_email}' for '#{opts[:username]}'. Using '#{opts[:email]}'"
    end

    opts[:name] = original_username if original_name.blank? && opts[:username] != original_username

    opts[:trust_level] = TrustLevel[1] unless opts[:trust_level]
    opts[:active] = opts.fetch(:active, true)
    opts[:import_mode] = true
    opts[:last_emailed_at] = opts.fetch(:last_emailed_at, Time.now)

    if (date_of_birth = opts[:date_of_birth]).is_a?(Date) && date_of_birth.year != 1904
      opts[:date_of_birth] = Date.new(1904, date_of_birth.month, date_of_birth.day)
    end

    u = User.new(opts)
    (opts[:custom_fields] || {}).each { |k, v| u.custom_fields[k] = v }
    u.custom_fields["import_id"] = import_id
    u.custom_fields["import_username"] = original_username if original_username.present? &&
      original_username != opts[:username]
    u.custom_fields["import_avatar_url"] = avatar_url if avatar_url.present?
    u.custom_fields["import_pass"] = opts[:password] if opts[:password].present?
    u.custom_fields["import_email"] = original_email if original_email != opts[:email]

    begin
      User.transaction do
        u.save!
        if bio_raw.present? || website.present? || location.present?
          if website.present?
            u.user_profile.website = website
            u.user_profile.website = nil unless u.user_profile.valid?
          end

          u.user_profile.bio_raw = bio_raw[0..2999] if bio_raw.present?
          u.user_profile.location = location if location.present?
          u.user_profile.save!
        end
      end

      u.activate if opts[:active] && opts[:password].present?
    rescue => e
      # try based on email
      if e.try(:record).try(:errors).try(:messages).try(:[], :primary_email).present?
        if existing = User.find_by_email(opts[:email].downcase)
          existing.created_at = opts[:created_at] if opts[:created_at]
          existing.custom_fields["import_id"] = import_id
          existing.save!
          u = existing
        end
      else
        puts "Error on record: #{original_opts.inspect}"
        raise e
      end
    end

    if u.custom_fields["import_email"]
      u.suspended_at = Time.zone.at(Time.now)
      u.suspended_till = 200.years.from_now
      u.save!

      user_option = u.user_option
      user_option.email_digests = false
      user_option.email_level = UserOption.email_level_types[:never]
      user_option.email_messages_level = UserOption.email_level_types[:never]
      user_option.save!
      if u.save
        StaffActionLogger.new(Discourse.system_user).log_user_suspend(
          u,
          "Invalid email address on import",
        )
      else
        Rails.logger.error(
          "Failed to suspend user #{u.username}. #{u.errors.try(:full_messages).try(:inspect)}",
        )
      end
    end

    post_create_action.try(:call, u) if u.persisted?

    u # If there was an error creating the user, u.errors has the messages
  end

  def find_existing_user(email, username)
    # Force the use of the index on the 'user_emails' table
    UserEmail.where("lower(email) = ?", email.downcase).first&.user ||
      User.where(username: username).first
  end

  def created_category(category)
    # override if needed
  end

  # Iterates through a collection to create categories.
  # The block should return a hash with attributes for the new category.
  # Required fields are :id and :name, where :id is the id of the
  # category in the original datasource. The given id will not be used to
  # create the Discourse category record.
  # Optional attributes are position, description, and parent_category_id.
  def create_categories(results)
    created = 0
    skipped = 0
    total = results.count

    results.each do |c|
      params = yield(c)

      # block returns nil to skip
      if params.nil? || category_id_from_imported_category_id(params[:id])
        skipped += 1
      else
        # Basic massaging on the category name
        params[:name] = "Blank" if params[:name].blank?
        params[:name].dup.strip!
        params[:name] = params[:name][0..49]

        # make sure categories don't go more than 2 levels deep
        if params[:parent_category_id]
          top = Category.find_by_id(params[:parent_category_id])
          top = top.parent_category while (top&.height_of_ancestors || -1) + 1 >=
            SiteSetting.max_category_nesting
          params[:parent_category_id] = top.id if top
        end

        new_category = create_category(params, params[:id])
        created_category(new_category)

        created += 1
      end

      print_status(created + skipped, total, get_start_time("categories"))
    end

    [created, skipped]
  end

  def create_category(opts, import_id)
    existing =
      Category
        .where(parent_category_id: opts[:parent_category_id])
        .where("LOWER(name) = ?", opts[:name].downcase.strip)
        .first

    if existing
      if import_id && existing.custom_fields["import_id"] != import_id
        existing.custom_fields["import_id"] = import_id
        existing.save!

        add_category(import_id, existing)
      end

      return existing
    end

    post_create_action = opts.delete(:post_create_action)

    new_category =
      Category.new(
        name: opts[:name],
        user_id: opts[:user_id] || opts[:user].try(:id) || Discourse::SYSTEM_USER_ID,
        position: opts[:position],
        parent_category_id: opts[:parent_category_id],
        color: opts[:color] || category_color(opts[:parent_category_id]),
        text_color: opts[:text_color] || "FFF",
        read_restricted: opts[:read_restricted] || false,
      )

    new_category.custom_fields["import_id"] = import_id if import_id
    new_category.save!

    if opts[:description].present?
      changes = { raw: opts[:description] }
      opts = { skip_revision: true, skip_validations: true, bypass_bump: true }
      new_category.topic.first_post.revise(Discourse.system_user, changes, opts)
    end

    add_category(import_id, new_category)

    post_create_action.try(:call, new_category)

    new_category
  end

  def category_color(parent_category_id)
    @category_colors ||= SiteSetting.category_colors.split("|")

    index = @next_category_color_index[parent_category_id].presence || 0
    @next_category_color_index[parent_category_id] = (
      if index + 1 >= @category_colors.count
        0
      else
        index + 1
      end
    )

    @category_colors[index]
  end

  def created_post(post)
    # override if needed
  end

  # Iterates through a collection of posts to be imported.
  # It can create topics and replies.
  # Attributes will be passed to the PostCreator.
  # Topics should give attributes title and category.
  # Replies should provide topic_id. Use topic_lookup_from_imported_post_id to find the topic.
  def create_posts(results, opts = {})
    skipped = 0
    created = 0
    total = opts[:total] || results.count
    start_time = get_start_time("posts-#{total}") # the post count should be unique enough to differentiate between posts and PMs

    results.each do |r|
      params = yield(r)

      # block returns nil to skip a post
      if params.nil?
        skipped += 1
      else
        import_id = params.delete(:id).to_s

        if post_id_from_imported_post_id(import_id)
          skipped += 1
        else
          begin
            new_post = create_post(params, import_id)
            if new_post.is_a?(Post)
              add_post(import_id, new_post)
              add_topic(new_post)
              created_post(new_post)
              created += 1
            else
              skipped += 1
              puts "Error creating post #{import_id}. Skipping."
              p new_post
            end
          rescue Discourse::InvalidAccess => e
            skipped += 1
            puts "InvalidAccess creating post #{import_id}. Topic is closed? #{e.message}"
          rescue => e
            skipped += 1
            puts "Exception while creating post #{import_id}. Skipping."
            puts e.message
            puts e.backtrace.join("\n")
          end
        end
      end

      print_status(created + skipped + (opts[:offset] || 0), total, start_time)
    end

    [created, skipped]
  end

  STAFF_GUARDIAN = Guardian.new(Discourse.system_user)

  def create_post(opts, import_id)
    user = User.find(opts[:user_id])
    post_create_action = opts.delete(:post_create_action)
    opts = opts.merge(skip_validations: true)
    opts[:import_mode] = true
    opts[:custom_fields] ||= {}
    opts[:custom_fields]["import_id"] = import_id

    unless opts[:topic_id]
      opts[:meta_data] = meta_data = {}
      meta_data["import_closed"] = true if opts[:closed]
      meta_data["import_archived"] = true if opts[:archived]
      meta_data["import_topic_id"] = opts[:import_topic_id] if opts[:import_topic_id]
    end

    opts[:guardian] = STAFF_GUARDIAN
    if @bbcode_to_md
      opts[:raw] = begin
        opts[:raw].bbcode_to_md(false, {}, :disable, :quote)
      rescue StandardError
        opts[:raw]
      end
    end

    post_creator = PostCreator.new(user, opts)
    post = post_creator.create
    post_create_action.try(:call, post) if post
    post && post_creator.errors.empty? ? post : post_creator.errors.full_messages
  end

  def create_upload(user_id, path, source_filename)
    @uploader.create_upload(user_id, path, source_filename)
  end

  # Iterate through a list of bookmark records to be imported.
  # Takes a collection, and yields to the block for each element.
  # Block should return a hash with the attributes for the bookmark.
  # Required fields are :user_id and :post_id, where both ids are
  # the values in the original datasource.
  def create_bookmarks(results, opts = {})
    created = 0
    skipped = 0
    total = opts[:total] || results.count

    user = User.new
    post = Post.new

    results.each do |result|
      params = yield(result)

      # only the IDs are needed, so this should be enough
      if params.nil?
        skipped += 1
      else
        user.id = user_id_from_imported_user_id(params[:user_id])
        post.id = post_id_from_imported_post_id(params[:post_id])

        if user.id.nil? || post.id.nil?
          skipped += 1
          puts "Skipping bookmark for user id #{params[:user_id]} and post id #{params[:post_id]}"
        else
          begin
            manager = BookmarkManager.new(user)
            bookmark = manager.create_for(bookmarkable_id: post.id, bookmarkable_type: "Post")

            created += 1 if manager.errors.none?
            skipped += 1 if manager.errors.any?
          rescue StandardError
            skipped += 1
          end
        end
      end

      print_status(created + skipped + (opts[:offset] || 0), total, get_start_time("bookmarks"))
    end

    [created, skipped]
  end

  def create_likes(results, opts = {})
    created = 0
    skipped = 0
    total = opts[:total] || results.count

    results.each do |result|
      params = yield(result)

      if params.nil?
        skipped += 1
      else
        created_by = User.find_by(id: user_id_from_imported_user_id(params[:user_id]))
        post = Post.find_by(id: post_id_from_imported_post_id(params[:post_id]))

        if created_by && post
          PostActionCreator.create(created_by, post, :like, created_at: params[:created_at])
          created += 1
        else
          skipped += 1
          puts "Skipping like for user id #{params[:user_id]} and post id #{params[:post_id]}"
        end
      end

      print_status(created + skipped + (opts[:offset] || 0), total, get_start_time("likes"))
    end

    [created, skipped]
  end

  def close_inactive_topics(opts = {})
    num_days = opts[:days] || 30
    puts "", "Closing topics that have been inactive for more than #{num_days} days."

    query = Topic.where("last_posted_at < ?", num_days.days.ago).where(closed: false)
    total_count = query.count
    closed_count = 0

    query.find_each do |topic|
      topic.update_status("closed", true, Discourse.system_user)
      closed_count += 1
      print_status(closed_count, total_count, get_start_time("close_inactive_topics"))
    end
  end

  def update_topic_status
    puts "", "Updating topic status"

    DB.exec <<~SQL
      UPDATE topics AS t
      SET closed = TRUE
      WHERE EXISTS(
          SELECT 1
          FROM topic_custom_fields AS f
          WHERE f.topic_id = t.id AND f.name = 'import_closed' AND f.value = 't'
      )
    SQL

    DB.exec <<~SQL
      UPDATE topics AS t
      SET archived = TRUE
      WHERE EXISTS(
          SELECT 1
          FROM topic_custom_fields AS f
          WHERE f.topic_id = t.id AND f.name = 'import_archived' AND f.value = 't'
      )
    SQL

    DB.exec <<~SQL
      DELETE FROM topic_custom_fields
      WHERE name IN ('import_closed', 'import_archived')
    SQL
  end

  def update_bumped_at
    puts "", "Updating bumped_at on topics"
    DB.exec <<~SQL
      UPDATE topics t
         SET bumped_at = COALESCE((SELECT MAX(created_at) FROM posts WHERE topic_id = t.id AND post_type = #{Post.types[:regular]}), bumped_at)
    SQL
  end

  def update_last_posted_at
    puts "", "Updating last posted at on users"

    DB.exec <<~SQL
      WITH lpa AS (
        SELECT user_id, MAX(posts.created_at) AS last_posted_at
        FROM posts
        GROUP BY user_id
      )
      UPDATE users
      SET last_posted_at = lpa.last_posted_at
      FROM users u1
      JOIN lpa ON lpa.user_id = u1.id
      WHERE u1.id = users.id
        AND users.last_posted_at IS DISTINCT FROM lpa.last_posted_at
    SQL
  end

  def update_user_stats
    puts "", "Updating first_post_created_at..."

    DB.exec <<~SQL
      WITH sub AS (
        SELECT user_id, MIN(posts.created_at) AS first_post_created_at
        FROM posts
        GROUP BY user_id
      )
      UPDATE user_stats
      SET first_post_created_at = sub.first_post_created_at
      FROM user_stats u1
      JOIN sub ON sub.user_id = u1.user_id
      WHERE u1.user_id = user_stats.user_id
        AND user_stats.first_post_created_at IS DISTINCT FROM sub.first_post_created_at
    SQL

    puts "", "Updating user post_count..."

    DB.exec <<~SQL
      WITH sub AS (
        SELECT user_id, COUNT(*) AS post_count
        FROM posts
        GROUP BY user_id
      )
      UPDATE user_stats
      SET post_count = sub.post_count
      FROM user_stats u1
      JOIN sub ON sub.user_id = u1.user_id
      WHERE u1.user_id = user_stats.user_id
        AND user_stats.post_count <> sub.post_count
    SQL

    puts "", "Updating user topic_count..."

    DB.exec <<~SQL
      WITH sub AS (
        SELECT user_id, COUNT(*) AS topic_count
        FROM topics
        GROUP BY user_id
      )
      UPDATE user_stats
      SET topic_count = sub.topic_count
      FROM user_stats u1
      JOIN sub ON sub.user_id = u1.user_id
      WHERE u1.user_id = user_stats.user_id
        AND user_stats.topic_count <> sub.topic_count
    SQL

    puts "", "Updating user digest_attempted_at..."

    DB.exec(
      "UPDATE user_stats SET digest_attempted_at = now() - random() * interval '1 week' WHERE digest_attempted_at IS NULL",
    )
  end

  # scripts that are able to import last_seen_at from the source data should override this method
  def update_last_seen_at
    puts "", "Updating last seen at on users"

    DB.exec("UPDATE users SET last_seen_at = created_at WHERE last_seen_at IS NULL")
    DB.exec("UPDATE users SET last_seen_at = last_posted_at WHERE last_posted_at IS NOT NULL")
  end

  def update_topic_users
    puts "", "Updating topic users"

    DB.exec <<~SQL
      INSERT INTO topic_users (user_id, topic_id, posted, last_read_post_number, first_visited_at, last_visited_at, total_msecs_viewed)
           SELECT user_id, topic_id, 't' , MAX(post_number), MIN(created_at), MAX(created_at), COUNT(id) * 5000
             FROM posts
            WHERE user_id > 0
         GROUP BY user_id, topic_id
      ON CONFLICT DO NOTHING
    SQL
  end

  def update_post_timings
    puts "", "Updating post timings"

    DB.exec <<~SQL
      INSERT INTO post_timings (topic_id, post_number, user_id, msecs)
           SELECT topic_id, post_number, user_id, 5000
             FROM posts
            WHERE user_id > 0
      ON CONFLICT DO NOTHING
    SQL
  end

  def update_feature_topic_users
    puts "", "Updating featured topic users"
    TopicFeaturedUsers.ensure_consistency!
  end

  def reset_topic_counters
    puts "", "Resetting topic counters"
    Topic.reset_all_highest!
  end

  def update_category_featured_topics
    puts "", "Updating featured topics in categories"

    count = 0
    total = Category.count

    Category.find_each do |category|
      CategoryFeaturedTopic.feature_topics_for(category)
      print_status(count += 1, total, get_start_time("category_featured_topics"))
    end
  end

  def update_tl0
    puts "", "Setting users with no posts to trust level 0"

    count = 0
    total = User.count

    User
      .includes(:user_stat)
      .find_each do |user|
        begin
          user.update_columns(trust_level: 0) if user.trust_level > 0 && user.post_count == 0
        rescue Discourse::InvalidAccess
        end
        print_status(count += 1, total, get_start_time("update_tl0"))
      end
  end

  def update_user_signup_date_based_on_first_post
    puts "", "Setting users' signup date based on the date of their first post"

    count = 0
    total = User.count

    User.find_each do |user|
      if first = user.posts.order("created_at ASC").first
        user.created_at = first.created_at
        user.save!
      end
      print_status(count += 1, total, get_start_time("user_signup"))
    end
  end

  def html_for_upload(upload, display_filename)
    @uploader.html_for_upload(upload, display_filename)
  end

  def embedded_image_html(upload)
    @uploader.embedded_image_html(upload)
  end

  def attachment_html(upload, display_filename)
    @uploader.attachment_html(upload, display_filename)
  end

  def print_status(current, max, start_time = nil)
    if start_time.present?
      elapsed_seconds = Time.now - start_time
      elements_per_minute = "[%.0f items/min]  " % [current / elapsed_seconds.to_f * 60]
    else
      elements_per_minute = ""
    end

    print "\r%9d / %d (%5.1f%%)  %s" % [current, max, current / max.to_f * 100, elements_per_minute]
  end

  def print_spinner
    @spinner_chars ||= %w[| / - \\]
    @spinner_chars.push @spinner_chars.shift
    print "\b#{@spinner_chars[0]}"
  end

  def get_start_time(key)
    @start_times.fetch(key) { |k| @start_times[k] = Time.now }
  end

  def batches(batch_size = 1000)
    offset = 0
    loop do
      yield offset
      offset += batch_size
    end
  end

  def fake_email
    SecureRandom.hex << "@email.invalid"
  end
end

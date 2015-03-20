if ARGV.include?('bbcode-to-md')
  # Replace (most) bbcode with markdown before creating posts.
  # This will dramatically clean up the final posts in Discourse.
  #
  # In a temp dir:
  #
  # git clone https://github.com/nlalonde/ruby-bbcode-to-md.git
  # cd ruby-bbcode-to-md
  # gem build ruby-bbcode-to-md.gemspec
  # gem install ruby-bbcode-to-md-0.0.13.gem
  require 'ruby-bbcode-to-md'
end

require_relative '../../config/environment'
require_dependency 'url_helper'
require_dependency 'file_helper'

module ImportScripts; end

class ImportScripts::Base

  include ActionView::Helpers::NumberHelper

  def initialize
    preload_i18n

    @bbcode_to_md = true if ARGV.include?('bbcode-to-md')
    @existing_groups = {}
    @failed_groups = []
    @existing_users = {}
    @failed_users = []
    @categories_lookup = {}
    @existing_posts = {}
    @topic_lookup = {}
    @site_settings_during_import
    @old_site_settings = {}
    @start_time = Time.now

    puts "loading existing groups..."
    GroupCustomField.where(name: 'import_id').pluck(:group_id, :value).each do |group_id, import_id|
      @existing_groups[import_id] = group_id
    end

    puts "loading existing users..."
    UserCustomField.where(name: 'import_id').pluck(:user_id, :value).each do |user_id, import_id|
      @existing_users[import_id] = user_id
    end

    puts "loading existing categories..."
    CategoryCustomField.where(name: 'import_id').pluck(:category_id, :value).each do |category_id, import_id|
      @categories_lookup[import_id] = category_id
    end

    puts "loading existing posts..."
    PostCustomField.where(name: 'import_id').pluck(:post_id, :value).each do |post_id, import_id|
      @existing_posts[import_id] = post_id
    end

    puts "loading existing topics..."
    Post.joins(:topic).pluck("posts.id, posts.topic_id, posts.post_number, topics.slug").each do |p|
      @topic_lookup[p[0]] = {
        topic_id: p[1],
        post_number: p[2],
        url: Post.url(p[3], p[1], p[2]),
      }
    end
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

    update_bumped_at
    update_last_posted_at
    update_last_seen_at
    update_feature_topic_users
    update_category_featured_topics
    update_topic_count_replies
    reset_topic_counters

    elapsed = Time.now - @start_time
    puts '', "Done (#{elapsed.to_s} seconds)"

  ensure
    reset_site_settings
  end

  def change_site_settings
    @site_settings_during_import = {
      email_domains_blacklist: '',
      min_topic_title_length: 1,
      min_post_length: 1,
      min_first_post_length: 1,
      min_private_message_post_length: 1,
      min_private_message_title_length: 1,
      allow_duplicate_topic_titles: true,
      disable_emails: true,
      authorized_extensions: '*'
    }

    @site_settings_during_import.each do |key, value|
      @old_site_settings[key] = SiteSetting.send(key)
      SiteSetting.set(key, value)
    end

    RateLimiter.disable
  end

  def reset_site_settings
    @old_site_settings.each do |key, value|
      current_value = SiteSetting.send(key)
      SiteSetting.set(key, value) unless current_value != @site_settings_during_import[key]
    end

    RateLimiter.enable
  end

  # Implementation will do most of its work in its execute method.
  # It will need to call create_users, create_categories, and create_posts.
  def execute
    raise NotImplementedError
  end

  # Get the Discourse Post id based on the id of the source record
  def post_id_from_imported_post_id(import_id)
    @existing_posts[import_id] || @existing_posts[import_id.to_s]
  end

  # Get the Discourse topic info (a hash) based on the id of the source record
  def topic_lookup_from_imported_post_id(import_id)
    post_id = post_id_from_imported_post_id(import_id)
    post_id ? @topic_lookup[post_id] : nil
  end

  # Get the Discourse Group id based on the id of the source group
  def group_id_from_imported_group_id(import_id)
    @existing_groups[import_id] || @existing_groups[import_id.to_s] || find_group_by_import_id(import_id).try(:id)
  end

  def find_group_by_import_id(import_id)
    GroupCustomField.where(name: 'import_id', value: import_id.to_s).first.try(:group)
  end

  # Get the Discourse User id based on the id of the source user
  def user_id_from_imported_user_id(import_id)
    @existing_users[import_id] || @existing_users[import_id.to_s] || find_user_by_import_id(import_id).try(:id)
  end

  def find_user_by_import_id(import_id)
    UserCustomField.where(name: 'import_id', value: import_id.to_s).first.try(:user)
  end

  # Get the Discourse Category id based on the id of the source category
  def category_id_from_imported_category_id(import_id)
    @categories_lookup[import_id] || @categories_lookup[import_id.to_s]
  end

  def create_admin(opts={})
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

  # Iterate through a list of groups to be imported.
  # Takes a collection and yields to the block for each element.
  # Block should return a hash with the attributes for each element.
  # Required fields are :id and :name, where :id is the id of the
  # group in the original datasource. The given id will not be used
  # to create the Discourse group record.
  def create_groups(results, opts={})
    groups_created = 0
    groups_skipped = 0
    total = opts[:total] || results.size

    results.each do |result|
      g = yield(result)

      if group_id_from_imported_group_id(g[:id])
        groups_skipped += 1
      else
        new_group = create_group(g, g[:id])

        if new_group.valid?
          @existing_groups[g[:id].to_s] = new_group.id
          groups_created += 1
        else
          @failed_groups << g
          puts "Failed to create group id #{g[:id]} #{new_group.name}: #{new_group.errors.full_messages}"
        end
      end

      print_status groups_created + groups_skipped + @failed_groups.length + (opts[:offset] || 0), total
    end

    return [groups_created, groups_skipped]
  end

  def create_group(opts, import_id)
    opts = opts.dup.tap {|o| o.delete(:id) }
    import_name = opts[:name]
    opts[:name] = UserNameSuggester.suggest(import_name)

    existing = Group.where(name: opts[:name]).first
    return existing if existing and existing.custom_fields["import_id"].to_i == import_id.to_i
    g = existing || Group.new(opts)
    g.custom_fields["import_id"] = import_id
    g.custom_fields["import_name"] = import_name

    g.tap(&:save)
  end

  # Iterate through a list of user records to be imported.
  # Takes a collection, and yields to the block for each element.
  # Block should return a hash with the attributes for the User model.
  # Required fields are :id and :email, where :id is the id of the
  # user in the original datasource. The given id will not be used to
  # create the Discourse user record.
  def create_users(results, opts={})
    users_created = 0
    users_skipped = 0
    total = opts[:total] || results.size

    results.each do |result|
      u = yield(result)

      # block returns nil to skip a user
      if u.nil?
        users_skipped += 1
      else
        import_id = u[:id]

        if user_id_from_imported_user_id(import_id)
          users_skipped += 1
        elsif u[:email].present?
          new_user = create_user(u, import_id)

          if new_user.valid?
            @existing_users[import_id.to_s] = new_user.id
            users_created += 1
          else
            @failed_users << u
            puts "Failed to create user id: #{import_id}, username: #{new_user.username}, email: #{new_user.email}: #{new_user.errors.full_messages}"
          end
        else
          @failed_users << u
          puts "Skipping user id #{import_id} because email is blank"
        end
      end

      print_status users_created + users_skipped + @failed_users.length + (opts[:offset] || 0), total
    end

    return [users_created, users_skipped]
  end

  def create_user(opts, import_id)
    opts.delete(:id)
    merge = opts.delete(:merge)
    post_create_action = opts.delete(:post_create_action)

    existing = User.where(email: opts[:email].downcase, username: opts[:username]).first
    return existing if existing && (merge || existing.custom_fields["import_id"].to_i == import_id.to_i)

    bio_raw = opts.delete(:bio_raw)
    website = opts.delete(:website)
    location = opts.delete(:location)
    avatar_url = opts.delete(:avatar_url)

    opts[:name] = User.suggest_name(opts[:email]) unless opts[:name]
    if opts[:username].blank? ||
      opts[:username].length < User.username_length.begin ||
      opts[:username].length > User.username_length.end ||
      opts[:username] =~ /[^A-Za-z0-9_]/ ||
      opts[:username][0] =~ /[^A-Za-z0-9]/ ||
      !User.username_available?(opts[:username])
      opts[:username] = UserNameSuggester.suggest(opts[:username] || opts[:name] || opts[:email])
    end
    opts[:email] = opts[:email].downcase
    opts[:trust_level] = TrustLevel[1] unless opts[:trust_level]
    opts[:active] = opts.fetch(:active, true)
    opts[:import_mode] = true
    opts[:last_emailed_at] = opts.fetch(:last_emailed_at, Time.now)

    u = User.new(opts)
    u.custom_fields["import_id"] = import_id
    u.custom_fields["import_username"] = opts[:username] if opts[:username].present?
    u.custom_fields["import_avatar_url"] = avatar_url if avatar_url.present?

    begin
      User.transaction do
        u.save!
        if bio_raw.present? || website.present? || location.present?
          u.user_profile.bio_raw = bio_raw if bio_raw.present?
          u.user_profile.website = website if website.present?
          u.user_profile.location = location if location.present?
          u.user_profile.save!
        end
      end
    rescue
      # try based on email
      existing = User.find_by(email: opts[:email].downcase)
      if existing
        existing.custom_fields["import_id"] = import_id
        existing.save!
        u = existing
      end
    end
    post_create_action.try(:call, u) if u.persisted?

    u # If there was an error creating the user, u.errors has the messages
  end

  # Iterates through a collection to create categories.
  # The block should return a hash with attributes for the new category.
  # Required fields are :id and :name, where :id is the id of the
  # category in the original datasource. The given id will not be used to
  # create the Discourse category record.
  # Optional attributes are position, description, and parent_category_id.
  def create_categories(results)
    results.each do |c|
      params = yield(c)

      # block returns nil to skip
      next if params.nil? || category_id_from_imported_category_id(params[:id])

      # Basic massaging on the category name
      params[:name] = "Blank" if params[:name].blank?
      params[:name].strip!
      params[:name] = params[:name][0..49]

      puts "\t#{params[:name]}"

      # make sure categories don't go more than 2 levels deep
      if params[:parent_category_id]
        top = Category.find_by_id(params[:parent_category_id])
        top = top.parent_category while top && !top.parent_category.nil?
        params[:parent_category_id] = top.id if top
      end

      new_category = create_category(params, params[:id])
      @categories_lookup[params[:id]] = new_category.id
    end
  end

  def create_category(opts, import_id)
    existing = Category.where("LOWER(name) = ?", opts[:name].downcase).first
    return existing if existing && existing.parent_category.try(:id) == opts[:parent_category_id]

    post_create_action = opts.delete(:post_create_action)

    new_category = Category.new(
      name: opts[:name],
      user_id: opts[:user_id] || opts[:user].try(:id) || -1,
      position: opts[:position],
      description: opts[:description],
      parent_category_id: opts[:parent_category_id]
    )

    new_category.custom_fields["import_id"] = import_id if import_id
    new_category.save!

    post_create_action.try(:call, new_category)

    new_category
  end

  def created_post(post)
    # override if needed
  end

  # Iterates through a collection of posts to be imported.
  # It can create topics and replies.
  # Attributes will be passed to the PostCreator.
  # Topics should give attributes title and category.
  # Replies should provide topic_id. Use topic_lookup_from_imported_post_id to find the topic.
  def create_posts(results, opts={})
    skipped = 0
    created = 0
    total = opts[:total] || results.size

    results.each do |r|
      params = yield(r)

      # block returns nil to skip a post
      if params.nil?
        skipped += 1
      else
        import_id = params.delete(:id).to_s

        if post_id_from_imported_post_id(import_id)
          skipped += 1 # already imported this post
        else
          begin
            new_post = create_post(params, import_id)
            if new_post.is_a?(Post)
              @existing_posts[import_id] = new_post.id
              @topic_lookup[new_post.id] = {
                post_number: new_post.post_number,
                topic_id: new_post.topic_id,
                url: new_post.url,
              }

              created_post(new_post)

              created += 1
            else
              skipped += 1
              puts "Error creating post #{import_id}. Skipping."
              puts new_post.inspect
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

      print_status skipped + created + (opts[:offset] || 0), total
    end

    return [created, skipped]
  end

  def create_post(opts, import_id)
    user = User.find(opts[:user_id])
    post_create_action = opts.delete(:post_create_action)
    opts = opts.merge(skip_validations: true)
    opts[:import_mode] = true
    opts[:custom_fields] ||= {}
    opts[:custom_fields]['import_id'] = import_id

    if @bbcode_to_md
      opts[:raw] = opts[:raw].bbcode_to_md(false) rescue opts[:raw]
    end

    post_creator = PostCreator.new(user, opts)
    post = post_creator.create
    post_create_action.try(:call, post) if post
    post ? post : post_creator.errors.full_messages
  end

  # Creates an upload.
  # Expects path to be the full path and filename of the source file.
  def create_upload(user_id, path, source_filename)
    tmp = Tempfile.new('discourse-upload')
    src = File.open(path)
    FileUtils.copy_stream(src, tmp)
    src.close
    tmp.rewind

    Upload.create_for(user_id, tmp, source_filename, tmp.size)
  ensure
    tmp.close rescue nil
    tmp.unlink rescue nil
  end

  # Iterate through a list of bookmark records to be imported.
  # Takes a collection, and yields to the block for each element.
  # Block should return a hash with the attributes for the bookmark.
  # Required fields are :user_id and :post_id, where both ids are
  # the values in the original datasource.
  def create_bookmarks(results, opts={})
    bookmarks_created = 0
    bookmarks_skipped = 0
    total = opts[:total] || results.size

    user = User.new
    post = Post.new

    results.each do |result|
      params = yield(result)

      # only the IDs are needed, so this should be enough
      user.id = user_id_from_imported_user_id(params[:user_id])
      post.id = post_id_from_imported_post_id(params[:post_id])

      if user.id.nil? || post.id.nil?
        bookmarks_skipped += 1
        puts "Skipping bookmark for user id #{params[:user_id]} and post id #{params[:post_id]}"
      else
        begin
          PostAction.act(user, post, PostActionType.types[:bookmark])
          bookmarks_created += 1
        rescue PostAction::AlreadyActed
          bookmarks_skipped += 1
        end

        print_status bookmarks_created + bookmarks_skipped + (opts[:offset] || 0), total
      end
    end
  end

  def close_inactive_topics(opts={})
    num_days = opts[:days] || 30
    puts '', "Closing topics that have been inactive for more than #{num_days} days."

    query = Topic.where('last_posted_at < ?', num_days.days.ago).where(closed: false)
    total_count = query.count
    closed_count = 0

    query.find_each do |topic|
      topic.update_status('closed', true, Discourse.system_user)
      closed_count += 1
      print_status(closed_count, total_count)
    end
  end

  def update_bumped_at
    puts "", "updating bumped_at on topics"
    Post.exec_sql("update topics t set bumped_at = COALESCE((select max(created_at) from posts where topic_id = t.id and post_type != #{Post.types[:moderator_action]}), bumped_at)")
  end

  def update_last_posted_at
    puts "", "updating last posted at on users"

    sql = <<-SQL
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
        AND users.last_posted_at <> lpa.last_posted_at
    SQL

    User.exec_sql(sql)
  end

  # scripts that are able to import last_seen_at from the source data should override this method
  def update_last_seen_at
    puts "", "updating last seen at on users"

    User.exec_sql("UPDATE users SET last_seen_at = created_at WHERE last_seen_at IS NULL")
    User.exec_sql("UPDATE users SET last_seen_at = last_posted_at WHERE last_posted_at IS NOT NULL")
  end

  def update_feature_topic_users
    puts "", "updating featured topic users"

    total_count = Topic.count
    progress_count = 0

    Topic.find_each do |topic|
      topic.feature_topic_users
      progress_count += 1
      print_status(progress_count, total_count)
    end
  end

  def reset_topic_counters
    puts "", "resetting topic counters"

    total_count = Topic.count
    progress_count = 0

    Topic.find_each do |topic|
      Topic.reset_highest(topic.id)
      progress_count += 1
      print_status(progress_count, total_count)
    end
  end

  def update_category_featured_topics
    puts "", "updating featured topics in categories"

    total_count = Category.count
    progress_count = 0

    Category.find_each do |category|
      CategoryFeaturedTopic.feature_topics_for(category)
      progress_count += 1
      print_status(progress_count, total_count)
    end
  end

  def update_topic_count_replies
    puts "", "updating user topic reply counts"

    total_count = User.real.count
    progress_count = 0

    User.real.find_each do |u|
      u.user_stat.update_topic_reply_count
      u.user_stat.save!
      progress_count += 1
      print_status(progress_count, total_count)
    end
  end

  def update_tl0
    puts "", "setting users with no posts to trust level 0"

    total_count = User.count
    progress_count = 0

    User.find_each do |user|
      user.change_trust_level!(0) if Post.where(user_id: user.id).count == 0
      progress_count += 1
      print_status(progress_count, total_count)
    end
  end

  def html_for_upload(upload, display_filename)
    if FileHelper.is_image?(upload.url)
      embedded_image_html(upload)
    else
      attachment_html(upload, display_filename)
    end
  end

  def embedded_image_html(upload)
    %Q[<img src="#{upload.url}" width="#{[upload.width, 640].compact.min}" height="#{[upload.height,480].compact.min}"><br/>]
  end

  def attachment_html(upload, display_filename)
    "<a class='attachment' href='#{upload.url}'>#{display_filename}</a> (#{number_to_human_size(upload.filesize)})"
  end

  def print_status(current, max)
    print "\r%9d / %d (%5.1f%%)  " % [current, max, ((current.to_f / max.to_f) * 100).round(1)]
  end

  def batches(batch_size)
    offset = 0
    loop do
      yield offset
      offset += batch_size
    end
  end
end

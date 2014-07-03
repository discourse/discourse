if ARGV.include?('bbcode-to-md')
  # Replace (most) bbcode with markdown before creating posts.
  # This will dramatically clean up the final posts in Discourse.
  #
  # In a temp dir:
  #
  # git clone git@github.com:nlalonde/ruby-bbcode-to-md.git
  # cd ruby-bbcode-to-md
  # gem build ruby-bbcode-to-md.gemspec
  # gem install ruby-bbcode-to-md-0.0.13.gem
  require 'ruby-bbcode-to-md'
end

module ImportScripts; end

class ImportScripts::Base

  def initialize
    require File.expand_path(File.dirname(__FILE__) + "/../../config/environment")

    @bbcode_to_md = true if ARGV.include?('bbcode-to-md')
    @existing_users = {}
    @failed_users = []
    @categories = {}
    @posts = {}
    @topic_lookup = {}

    UserCustomField.where(name: 'import_id').pluck(:user_id, :value).each do |user_id, import_id|
      @existing_users[import_id] = user_id
    end

    CategoryCustomField.where(name: 'import_id').pluck(:category_id, :value).each do |category_id, import_id|
      @categories[import_id] = Category.find(category_id.to_i)
    end

    PostCustomField.where(name: 'import_id').pluck(:post_id, :value).each do |post_id, import_id|
      @posts[import_id] = post_id
    end

    Post.pluck(:id, :topic_id, :post_number).each do |p,t,n|
      @topic_lookup[p] = {topic_id: t, post_number: n}
    end
  end

  def perform
    Rails.logger.level = 3 # :error, so that we don't create log files that are many GB

    SiteSetting.email_domains_blacklist = ''
    SiteSetting.min_topic_title_length = 1
    SiteSetting.min_post_length = 1
    SiteSetting.min_private_message_post_length = 1
    SiteSetting.min_private_message_title_length = 1
    SiteSetting.allow_duplicate_topic_titles = true

    RateLimiter.disable

    execute

    update_bumped_at
    update_feature_topic_users
    update_category_featured_topics
    update_topic_count_replies

    puts '', 'Done'

  ensure
    RateLimiter.enable
  end

  # Implementation will do most of its work in its execute method.
  # It will need to call create_users, create_categories, and create_posts.
  def execute
    raise NotImplementedError
  end

  # Get the Discourse Post id based on the id of the source record
  def post_id_from_imported_post_id(import_id)
    @posts[import_id] || @posts[import_id.to_s]
  end

  # Get the Discourse topic info (a hash) based on the id of the source record
  def topic_lookup_from_imported_post_id(import_id)
    post_id = post_id_from_imported_post_id(import_id)
    post_id ? @topic_lookup[post_id] : nil
  end

  # Get the Discourse User id based on the id of the source user
  def user_id_from_imported_user_id(import_id)
    @existing_users[import_id] || @existing_users[import_id.to_s] || find_user_by_import_id(import_id)
  end

  def find_user_by_import_id(import_id)
    UserCustomField.where(name: 'import_id', value: import_id.to_s).first.try(:user)
  end

  # Get the Discourse Category id based on the id of the source category
  def category_from_imported_category_id(import_id)
    @categories[import_id] || @categories[import_id.to_s]
  end

  def create_admin(opts={})
    admin = User.new
    admin.email = opts[:email] || "sam.saffron@gmail.com"
    admin.username = opts[:username] || "sam"
    admin.password = SecureRandom.uuid
    admin.save!
    admin.grant_admin!
    admin.change_trust_level!(:regular)
    admin.email_tokens.update_all(confirmed: true)
    admin
  end

  # Iterate through a list of user records to be imported.
  # Takes a collection, and yields to the block for each element.
  # Block should return a hash with the attributes for the User model.
  # Required fields are :id and :email, where :id is the id of the
  # user in the original datasource. The given id will not be used to
  # create the Discourse user record.
  def create_users(results)
    puts "creating users"
    num_users_before = User.count
    users_created = 0
    users_skipped = 0
    progress = 0

    results.each do |result|
      u = yield(result)

      if user_id_from_imported_user_id(u[:id])
        users_skipped += 1
      elsif u[:email].present?
        new_user = create_user(u, u[:id])

        if new_user.valid?
          @existing_users[u[:id].to_s] = new_user.id
          users_created += 1
        else
          @failed_users << u
          puts "Failed to create user id #{u[:id]} #{new_user.email}: #{new_user.errors.full_messages}"
        end
      else
        @failed_users << u
        puts "Skipping user id #{u[:id]} because email is blank"
      end

      print_status users_created + users_skipped + @failed_users.length, results.size
    end

    puts ''
    puts "created: #{User.count - num_users_before} users"
    puts " failed: #{@failed_users.size}" if @failed_users.size > 0
  end

  def create_user(opts, import_id)
    opts.delete(:id)
    existing = User.where(email: opts[:email].downcase, username: opts[:username]).first
    return existing if existing and existing.custom_fields["import_id"].to_i == import_id.to_i

    bio_raw = opts.delete(:bio_raw)
    opts[:name] = User.suggest_name(opts[:name]) if opts[:name]
    opts[:username] = UserNameSuggester.suggest((opts[:username].present? ? opts[:username] : nil) || opts[:name] || opts[:email])
    opts[:email] = opts[:email].downcase
    opts[:trust_level] = TrustLevel.levels[:basic] unless opts[:trust_level]

    u = User.new(opts)
    u.custom_fields["import_id"] = import_id
    u.custom_fields["import_username"] = opts[:username] if opts[:username].present?

    begin
      User.transaction do
        u.save!
        if bio_raw.present?
          u.user_profile.bio_raw = bio_raw
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

    u # If there was an error creating the user, u.errors has the messages
  end

  # Iterates through a collection to create categories.
  # The block should return a hash with attributes for the new category.
  # Required fields are :id and :name, where :id is the id of the
  # category in the original datasource. The given id will not be used to
  # create the Discourse category record.
  # Optional attributes are position, description, and parent_category_id.
  def create_categories(results)
    puts "creating categories"

    results.each do |c|
      params = yield(c)
      puts "    #{params[:name]}"
      new_category = create_category(params, params[:id])
      @categories[params[:id]] = new_category
    end
  end

  def create_category(opts, import_id)
    existing = category_from_imported_category_id(import_id)
    return existing if existing

    new_category = Category.new(
      name: opts[:name],
      user_id: -1,
      position: opts[:position],
      description: opts[:description],
      parent_category_id: opts[:parent_category_id]
    )
    new_category.custom_fields["import_id"] = import_id if import_id
    new_category.save!
    new_category
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

      if params.nil?
        skipped += 1
        next # block returns nil to skip a post
      end

      import_id = params.delete(:id).to_s

      if post_id_from_imported_post_id(import_id)
        skipped += 1 # already imported this post
      else
        begin
          new_post = create_post(params, import_id)
          @posts[import_id] = new_post.id
          @topic_lookup[new_post.id] = {post_number: new_post.post_number, topic_id: new_post.topic_id}

          created += 1
        rescue => e
          skipped += 1
          puts "Error creating post #{import_id}. Skipping."
          puts e.message
        rescue Discourse::InvalidAccess => e
          skipped += 1
          puts "InvalidAccess creating post #{import_id}. Topic is closed? #{e.message}"
        end
      end

      print_status skipped + created + (opts[:offset] || 0), total
    end

    return [created, skipped]
  end

  def create_post(opts, import_id)
    user = User.find(opts[:user_id])
    opts = opts.merge(skip_validations: true)
    opts[:import_mode] = true
    opts[:custom_fields] ||= {}
    opts[:custom_fields]['import_id'] = import_id

    if @bbcode_to_md
      opts[:raw] = opts[:raw].bbcode_to_md rescue opts[:raw]
    end

    PostCreator.create(user, opts)
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
    puts '', "updating bumped_at on topics"
    Post.exec_sql("update topics t set bumped_at = (select max(created_at) from posts where topic_id = t.id and post_type != #{Post.types[:moderator_action]})")
  end

  def update_feature_topic_users
    puts "updating featured topic users"

    total_count = Topic.count
    progress_count = 0

    Topic.find_each do |topic|
      topic.feature_topic_users
      progress_count += 1
      print_status(progress_count, total_count)
    end
  end

  def update_category_featured_topics
    puts '', "updating featured topics in categories"
    Category.find_each do |category|
      CategoryFeaturedTopic.feature_topics_for(category)
    end
  end

  def update_topic_count_replies
    puts "updating user topic reply counts"

    total_count = User.real.count
    progress_count = 0

    User.real.find_each do |u|
      u.user_stat.update_topic_reply_count
      u.user_stat.save!
      progress_count += 1
      print_status(progress_count, total_count)
    end
  end

  def print_status(current, max)
    print "\r%9d / %d (%5.1f%%)    " % [current, max, ((current.to_f / max.to_f) * 100).round(1)]
  end

  def batches(batch_size)
    offset = 0
    loop do
      yield offset
      offset += batch_size
    end
  end
end

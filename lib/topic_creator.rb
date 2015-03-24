class TopicCreator

  attr_accessor :errors

  def self.create(user, guardian, opts)
    self.new(user, guardian, opts).create
  end

  def initialize(user, guardian, opts)
    @user = user
    @guardian = guardian
    @opts = opts
    @added_users = []
  end

  def create
    @topic = Topic.new(setup_topic_params)

    setup_auto_close_time
    process_private_message
    save_topic
    create_warning
    watch_topic

    @topic
  end

  private

  def create_warning
    return unless @opts[:is_warning]

    # We can only attach warnings to PMs
    unless @topic.private_message?
      @topic.errors.add(:base, :warning_requires_pm)
      @errors = @topic.errors
      raise ActiveRecord::Rollback.new
    end

    # Don't create it if there is more than one user
    if @added_users.size != 1
      @topic.errors.add(:base, :too_many_users)
      @errors = @topic.errors
      raise ActiveRecord::Rollback.new
    end

    # Create a warning record
    Warning.create(topic: @topic, user: @added_users.first, created_by: @user)
  end

  def watch_topic
    unless @opts[:auto_track] == false
      @topic.notifier.watch_topic!(@topic.user_id)
    end

    user_ids = @topic.topic_allowed_users(true).pluck(:user_id)
    user_ids += @topic.topic_allowed_groups(true).map { |t| t.group.users.pluck(:id) }.flatten

    user_ids.uniq.reject{ |id| id == @topic.user_id }.each do |user_id|
      @topic.notifier.watch_topic!(user_id, nil) unless user_id == -1
    end

    CategoryUser.auto_watch_new_topic(@topic)
    CategoryUser.auto_track_new_topic(@topic)
  end

  def setup_topic_params
    topic_params = {
      title: @opts[:title],
      user_id: @user.id,
      last_post_user_id: @user.id
    }

    [:subtype, :archetype, :meta_data, :import_mode].each do |key|
      topic_params[key] = @opts[key] if @opts[key].present?
    end

    # Automatically give it a moderator warning subtype if specified
    topic_params[:subtype] = TopicSubtype.moderator_warning if @opts[:is_warning]

    category = find_category

    @guardian.ensure_can_create!(Topic, category)

    topic_params[:category_id] = category.id if category.present?

    topic_params[:created_at] = Time.zone.parse(@opts[:created_at].to_s) if @opts[:created_at].present?

    topic_params[:pinned_at] = Time.zone.parse(@opts[:pinned_at].to_s) if @opts[:pinned_at].present?
    topic_params[:pinned_globally] = @opts[:pinned_globally] if @opts[:pinned_globally].present?

    topic_params
  end

  def find_category
    # PM can't have a category
    @opts.delete(:category) if @opts[:archetype].present? && @opts[:archetype] == Archetype.private_message

    # Temporary fix to allow older clients to create topics.
    # When all clients are updated the category variable should
    # be set directly to the contents of the if statement.
    if (@opts[:category].is_a? Integer) || (@opts[:category] =~ /^\d+$/)
      Category.find_by(id: @opts[:category])
    else
      Category.find_by(name_lower: @opts[:category].try(:downcase))
    end
  end

  def setup_auto_close_time
    return unless @opts[:auto_close_time].present?
    return unless @guardian.can_moderate?(@topic)
    @topic.set_auto_close(@opts[:auto_close_time], @user)
  end

  def process_private_message
    return unless @opts[:archetype] == Archetype.private_message
    @topic.subtype = TopicSubtype.user_to_user unless @topic.subtype

    unless @opts[:target_usernames].present? || @opts[:target_group_names].present?
      @topic.errors.add(:base, :no_user_selected)
      @errors = @topic.errors
      raise ActiveRecord::Rollback.new
    end

    add_users(@topic,@opts[:target_usernames])
    add_groups(@topic,@opts[:target_group_names])
    @topic.topic_allowed_users.build(user_id: @user.id)
  end

  def save_topic
    unless @topic.save(validate: !@opts[:skip_validations])
      @errors = @topic.errors
      raise ActiveRecord::Rollback.new
    end
  end

  def add_users(topic, usernames)
    return unless usernames
    User.where(username: usernames.split(',')).each do |user|
      check_can_send_permission!(topic, user)
      @added_users << user
      topic.topic_allowed_users.build(user_id: user.id)
    end
  end

  def add_groups(topic, groups)
    return unless groups
    Group.where(name: groups.split(',')).each do |group|
      check_can_send_permission!(topic,group)
      topic.topic_allowed_groups.build(group_id: group.id)
    end
  end

  def check_can_send_permission!(topic,item)
    unless @guardian.can_send_private_message?(item)
      topic.errors.add(:base, :cant_send_pm)
      @errors = topic.errors
      raise ActiveRecord::Rollback.new
    end
  end
end

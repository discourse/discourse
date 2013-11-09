class TopicCreator

  attr_accessor :errors

  def self.create(user, guardian, opts)
    self.new(user, guardian, opts).create
  end

  def initialize(user, guardian, opts)
    @user = user
    @guardian = guardian
    @opts = opts
  end

  def create
    topic_params = setup
    @topic = Topic.new(topic_params)

    setup_auto_close_days if @opts[:auto_close_days]

    process_private_message if @opts[:archetype] == Archetype.private_message
    save_topic

    watch_topic

    @topic
  end

  private

  def watch_topic
    unless @opts[:auto_track] == false
      @topic.notifier.watch_topic!(@topic.user_id)
    end
  end

  def setup
    topic_params = {title: @opts[:title], user_id: @user.id, last_post_user_id: @user.id}
    topic_params[:archetype] = @opts[:archetype] if @opts[:archetype].present?
    topic_params[:subtype] = @opts[:subtype] if @opts[:subtype].present?

    # Temporary fix to allow older clients to create topics.
    # When all clients are updated the category variable should
    # be set directly to the contents of the if statement.
    category = if (@opts[:category].is_a? Integer) || (@opts[:category] =~ /^\d+$/)
      Category.where(id: @opts[:category]).first
    else
      Category.where(name: @opts[:category]).first
    end

    @guardian.ensure_can_create!(Topic,category)
    topic_params[:category_id] = category.id if category.present?
    topic_params[:meta_data] = @opts[:meta_data] if @opts[:meta_data].present?
    topic_params[:created_at] = Time.zone.parse(@opts[:created_at].to_s) if @opts[:created_at].present?
    topic_params
  end

  def setup_auto_close_days
    @guardian.ensure_can_moderate!(@topic)
    @topic.auto_close_days = @opts[:auto_close_days]
  end

  def process_private_message
    @topic.subtype = TopicSubtype.user_to_user unless @topic.subtype

    unless @opts[:target_usernames].present? || @opts[:target_group_names].present?
      @topic.errors.add(:archetype, :cant_send_pm)
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
      check_can_send_permission!(topic,user)
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
      topic.errors.add(:archetype, :cant_send_pm)
      @errors = topic.errors
      raise ActiveRecord::Rollback.new
    end
  end
end

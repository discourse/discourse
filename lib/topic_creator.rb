require_dependency 'has_errors'

class TopicCreator

  attr_reader :user, :guardian, :opts

  include HasErrors

  def self.create(user, guardian, opts)
    self.new(user, guardian, opts).create
  end

  def initialize(user, guardian, opts)
    @user = user
    @guardian = guardian
    @opts = opts
    @added_users = []
  end

  def valid?
    topic = Topic.new(setup_topic_params)
    # validate? will clear the error hash
    # so we fire the validation event after
    # this allows us to add errors
    valid = topic.valid?

    # not sure where this should go
    if !@guardian.is_staff? && staff_only = DiscourseTagging.staff_only_tags(@opts[:tags])
      topic.errors[:base] << I18n.t("tags.staff_tag_disallowed", tag: staff_only.join(" "))
    end

    DiscourseEvent.trigger(:after_validate_topic, topic, self)
    valid &&= topic.errors.empty?

    add_errors_from(topic) unless valid

    valid
  end

  def create
    topic = Topic.new(setup_topic_params)
    setup_tags(topic)

    DiscourseEvent.trigger(:before_create_topic, topic, self)

    setup_auto_close_time(topic)
    process_private_message(topic)
    save_topic(topic)
    create_warning(topic)
    watch_topic(topic)

    topic
  end

  private

  def create_warning(topic)
    return unless @opts[:is_warning]

    # We can only attach warnings to PMs
    rollback_with!(topic, :warning_requires_pm) unless topic.private_message?

    # Don't create it if there is more than one user
    rollback_with!(topic, :too_many_users) if @added_users.size != 1

    # Create a warning record
    Warning.create(topic: topic, user: @added_users.first, created_by: @user)
  end

  def watch_topic(topic)
    unless @opts[:auto_track] == false
      topic.notifier.watch_topic!(topic.user_id)
    end

    topic.topic_allowed_users(true).each do |tau|
      next if tau.user_id == -1 || tau.user_id == topic.user_id
      topic.notifier.watch!(tau.user_id)
    end

    topic.topic_allowed_groups(true).each do |tag|
      tag.group.group_users.each do |gu|
        next if gu.user_id == -1 || gu.user_id == topic.user_id
        action = case gu.notification_level
                 when TopicUser.notification_levels[:tracking] then "track!"
                 when TopicUser.notification_levels[:regular]  then "regular!"
                 when TopicUser.notification_levels[:muted]    then "mute!"
                 when TopicUser.notification_levels[:watching] then "watch!"
                 else "track!"
                 end
        topic.notifier.send(action, gu.user_id)
      end
    end

    unless topic.private_message?
      # In order of importance:
      CategoryUser.auto_watch_new_topic(topic)
      CategoryUser.auto_track_new_topic(topic)
      TagUser.auto_watch_new_topic(topic)
      TagUser.auto_track_new_topic(topic)
    end
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

    if topic_params[:import_mode] && @opts[:views].to_i > 0
      topic_params[:views] = @opts[:views].to_i
    end

    # Automatically give it a moderator warning subtype if specified
    topic_params[:subtype] = TopicSubtype.moderator_warning if @opts[:is_warning]

    category = find_category

    @guardian.ensure_can_create!(Topic, category) unless (@opts[:skip_validations] || @opts[:archetype] == Archetype.private_message)

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

  def setup_tags(topic)
    DiscourseTagging.tag_topic_by_names(topic, @guardian, @opts[:tags])
  end

  def setup_auto_close_time(topic)
    return unless @opts[:auto_close_time].present?
    return unless @guardian.can_moderate?(topic)
    topic.set_auto_close(@opts[:auto_close_time], {by_user: @user})
  end

  def process_private_message(topic)
    return unless @opts[:archetype] == Archetype.private_message
    topic.subtype = TopicSubtype.user_to_user unless topic.subtype

    unless @opts[:target_usernames].present? || @opts[:target_group_names].present?
      rollback_with!(topic, :no_user_selected)
    end

    add_users(topic,@opts[:target_usernames])
    add_groups(topic,@opts[:target_group_names])
    topic.topic_allowed_users.build(user_id: @user.id)
  end

  def save_topic(topic)
    topic.disable_rate_limits! if @opts[:skip_validations]

    unless topic.save(validate: !@opts[:skip_validations])
      rollback_from_errors!(topic)
    end
  end

  def add_users(topic, usernames)
    return unless usernames

    names = usernames.split(',').flatten
    len = 0

    User.where(username: names).each do |user|
      check_can_send_permission!(topic, user)
      @added_users << user
      topic.topic_allowed_users.build(user_id: user.id)
      len += 1
    end

    rollback_with!(topic, :target_user_not_found) unless len == names.length
  end

  def add_groups(topic, groups)
    return unless groups
    names = groups.split(',').flatten
    len = 0

    Group.where(name: names).each do |group|
      check_can_send_permission!(topic, group)
      topic.topic_allowed_groups.build(group_id: group.id)
      len += 1
      group.update_columns(has_messages: true) unless group.has_messages
    end

    rollback_with!(topic, :target_group_not_found) unless len == names.length
  end

  def check_can_send_permission!(topic, obj)
    rollback_with!(topic, :cant_send_pm) unless @opts[:skip_validations] || @guardian.can_send_private_message?(obj)
  end
end

# frozen_string_literal: true

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

    validate_visibility(topic)

    category = find_category
    if category.present? && guardian.can_tag?(topic)
      tags = @opts[:tags].presence || []

      # adds topic.errors
      DiscourseTagging.validate_category_tags(guardian, topic, category, tags)
    end

    DiscourseEvent.trigger(:after_validate_topic, topic, self)
    valid &&= topic.errors.empty?

    add_errors_from(topic) unless valid

    valid
  end

  def create
    topic = Topic.new(setup_topic_params)

    validate_visibility!(topic)
    setup_tags(topic)

    if fields = @opts[:custom_fields]
      topic.custom_fields = fields
    end

    DiscourseEvent.trigger(:before_create_topic, topic, self)

    setup_auto_close_time(topic)
    process_private_message(topic)
    save_topic(topic)
    create_warning(topic)
    watch_topic(topic)
    create_shared_draft(topic)
    UserActionManager.topic_created(topic)

    topic
  end

  private

  def validate_visibility(topic)
    if !@opts[:skip_validations] && !topic.visible &&
         !guardian.can_create_unlisted_topic?(topic, !!opts[:embed_url])
      topic.errors.add(:base, :unable_to_unlist)
    end
  end

  def validate_visibility!(topic)
    validate_visibility(topic)

    rollback_from_errors!(topic) if topic.errors.full_messages.present?
  end

  def create_shared_draft(topic)
    return if @opts[:shared_draft].blank? || @opts[:shared_draft] == "false"

    category_id =
      @opts[:category].blank? ? SiteSetting.shared_drafts_category.to_i : @opts[:category]
    SharedDraft.create(topic_id: topic.id, category_id: category_id)
  end

  def create_warning(topic)
    return unless @opts[:is_warning]

    # We can only attach warnings to PMs
    rollback_with!(topic, :warning_requires_pm) unless topic.private_message?

    # Don't create it if there is more than one user
    rollback_with!(topic, :too_many_users) if @added_users.size != 1

    # Create a warning record
    UserWarning.create(topic: topic, user: @added_users.first, created_by: @user)
  end

  def watch_topic(topic)
    topic.notifier.watch_topic!(topic.user_id) unless @opts[:auto_track] == false

    topic.reload.topic_allowed_users.each do |tau|
      next if tau.user_id == -1 || tau.user_id == topic.user_id
      topic.notifier.watch!(tau.user_id)
    end

    topic.reload.topic_allowed_groups.each do |topic_allowed_group|
      group = topic_allowed_group.group

      begin
        group.set_message_default_notification_levels!(topic)
      rescue Group::GroupPmUserLimitExceededError => e
        rollback_with!(
          topic,
          :too_large_group,
          group_name: group.name,
          limit: SiteSetting.group_pm_user_limit,
        )
      end
    end
  end

  def setup_topic_params
    @opts[:visible] = true if @opts[:visible].nil?

    topic_params = {
      title: @opts[:title],
      user_id: @user.id,
      last_post_user_id: @user.id,
      visible: @opts[:visible],
    }

    %i[subtype archetype import_mode advance_draft].each do |key|
      topic_params[key] = @opts[key] if @opts[key].present?
    end

    if topic_params[:import_mode] && @opts[:views].to_i > 0
      topic_params[:views] = @opts[:views].to_i
    end

    if topic_params[:import_mode] && @opts[:participant_count].to_i > 0
      topic_params[:participant_count] = @opts[:participant_count].to_i
    end

    # Automatically give it a moderator warning subtype if specified
    topic_params[:subtype] = TopicSubtype.moderator_warning if @opts[:is_warning]

    category = find_category
    unless (@opts[:skip_validations] || @opts[:archetype] == Archetype.private_message)
      @guardian.ensure_can_create!(Topic, category)
    end

    raise Discourse::InvalidParameters.new(:category) if @opts[:category].present? && category.nil?

    topic_params[:category_id] = category.id if category.present?
    topic_params[:created_at] = convert_time(@opts[:created_at]) if @opts[:created_at].present?
    topic_params[:pinned_at] = convert_time(@opts[:pinned_at]) if @opts[:pinned_at].present?
    topic_params[:pinned_globally] = @opts[:pinned_globally] if @opts[:pinned_globally].present?
    topic_params[:external_id] = @opts[:external_id] if @opts[:external_id].present?
    topic_params[:featured_link] = @opts[:featured_link]

    topic_params
  end

  def convert_time(timestamp)
    if timestamp.is_a?(Time)
      timestamp
    else
      Time.zone.parse(timestamp.to_s)
    end
  end

  def find_category
    @category ||=
      begin
        # PM can't have a category
        if @opts[:archetype].present? && @opts[:archetype] == Archetype.private_message
          @opts.delete(:category)
        end

        return Category.find(SiteSetting.shared_drafts_category) if @opts[:shared_draft]

        if (@opts[:category].is_a? Integer) || (@opts[:category] =~ /\A\d+\z/)
          Category.find_by(id: @opts[:category])
        end
      end
  end

  def setup_tags(topic)
    if @opts[:tags].present?
      # We can try the full tagging workflow which does validations and other
      # things like replacing synonyms first, but if this fails then we can try
      # the simple workflow if validations are skipped.
      valid_tags = DiscourseTagging.tag_topic_by_names(topic, @guardian, @opts[:tags])
      if !valid_tags
        if @opts[:skip_validations]
          DiscourseTagging.add_or_create_tags_by_name(topic, @opts[:tags])
        else
          topic.errors.add(:base, :unable_to_tag)
          rollback_from_errors!(topic)
        end
      end
    end

    watched_words = WordWatcher.words_for_action(:tag)
    if watched_words.present?
      word_watcher = WordWatcher.new("#{@opts[:title]} #{@opts[:raw]}")
      word_watcher_tags = topic.tags.map(&:name)
      watched_words.each do |_, opts|
        if word_watcher.word_matches?(opts[:word], case_sensitive: opts[:case_sensitive])
          word_watcher_tags += opts[:replacement].split(",")
        end
      end
      DiscourseTagging.tag_topic_by_names(topic, Discourse.system_user.guardian, word_watcher_tags)
    end
  end

  def setup_auto_close_time(topic)
    return if @opts[:auto_close_time].blank?
    return unless @guardian.can_moderate?(topic)
    topic.set_auto_close(@opts[:auto_close_time], by_user: @user)
  end

  def process_private_message(topic)
    return unless @opts[:archetype] == Archetype.private_message
    topic.subtype = TopicSubtype.user_to_user unless topic.subtype

    if @opts[:target_usernames].blank? && @opts[:target_emails].blank? &&
         @opts[:target_group_names].blank?
      rollback_with!(topic, :no_user_selected)
    end

    if @opts[:target_emails].present? && !@guardian.can_send_private_messages_to_email?
      rollback_with!(topic, :send_to_email_disabled)
    end

    add_users(topic, @opts[:target_usernames])
    add_emails(topic, @opts[:target_emails])
    add_groups(topic, @opts[:target_group_names])

    topic.topic_allowed_users.build(user_id: @user.id) if !@added_users.include?(user)
  end

  def save_topic(topic)
    topic.disable_rate_limits! if @opts[:skip_validations]

    rollback_from_errors!(topic) unless topic.save(validate: !@opts[:skip_validations])
  end

  def add_users(topic, usernames)
    return unless usernames

    names = usernames.split(",").flatten.map(&:downcase)
    len = 0

    User
      .includes(:user_option)
      .where("username_lower in (?)", names)
      .find_each do |user|
        check_can_send_permission!(topic, user)
        @added_users << user
        topic.topic_allowed_users.build(user_id: user.id)
        len += 1
      end

    rollback_with!(topic, :target_user_not_found) unless len == names.length
  end

  def add_emails(topic, emails)
    return unless emails

    begin
      emails = emails.split(",").flatten
      len = 0

      emails.each do |email|
        display_name = email.split("@").first

        if user = find_or_create_user(email, display_name)
          if !@added_users.include?(user)
            @added_users << user
            topic.topic_allowed_users.build(user_id: user.id)
          end
          len += 1
        end
      end
    ensure
      rollback_with!(topic, :target_user_not_found) unless len == emails.length
    end
  end

  def add_groups(topic, groups)
    return unless groups
    names = groups.split(",").flatten.map(&:downcase)
    len = 0

    Group
      .where("lower(name) in (?)", names)
      .each do |group|
        check_can_send_permission!(topic, group)
        topic.topic_allowed_groups.build(group_id: group.id)
        len += 1
        group.update_columns(has_messages: true) unless group.has_messages
      end

    rollback_with!(topic, :target_group_not_found) unless len == names.length
  end

  def check_can_send_permission!(topic, obj)
    unless @opts[:skip_validations] ||
             @guardian.can_send_private_message?(
               obj,
               notify_moderators: topic&.subtype == TopicSubtype.notify_moderators,
             )
      rollback_with!(topic, :cant_send_pm)
    end
  end

  def find_or_create_user(email, display_name)
    user = User.find_by_email(email)

    if !user && SiteSetting.enable_staged_users
      username = UserNameSuggester.sanitize_username(display_name) if display_name.present?

      user =
        User.create!(
          email: email,
          username: UserNameSuggester.suggest(username.presence || email),
          name: display_name.presence || User.suggest_name(email),
          staged: true,
        )
    end

    user
  end
end

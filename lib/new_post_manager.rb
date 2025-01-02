# frozen_string_literal: true

# Determines what actions should be taken with new posts.
#
# The default action is to create the post, but this can be extended
# with `NewPostManager.add_handler` to take other approaches depending
# on the user or input.
class NewPostManager
  attr_reader :user, :args

  def self.sorted_handlers
    @sorted_handlers ||= clear_handlers!
  end

  def self.handlers
    sorted_handlers.map { |h| h[:proc] }
  end

  def self.plugin_payload_attributes
    @payload_attributes ||= []
  end

  def self.add_plugin_payload_attribute(attribute)
    plugin_payload_attributes << attribute
  end

  def self.clear_handlers!
    @sorted_handlers = []
  end

  def self.add_handler(priority = 0, &block)
    sorted_handlers << { priority: priority, proc: block }
    @sorted_handlers.sort_by! { |h| -h[:priority] }
  end

  def self.is_first_post?(manager)
    user = manager.user
    args = manager.args

    !!(args[:first_post_checks] && user.post_count == 0 && user.topic_count == 0)
  end

  def self.is_fast_typer?(manager)
    args = manager.args

    is_first_post?(manager) &&
      args[:typing_duration_msecs].to_i < SiteSetting.min_first_post_typing_time &&
      SiteSetting.auto_silence_fast_typers_on_first_post &&
      manager.user.trust_level <= SiteSetting.auto_silence_fast_typers_max_trust_level
  end

  def self.auto_silence?(manager)
    is_first_post?(manager) &&
      WordWatcher.new("#{manager.args[:title]} #{manager.args[:raw]}").should_silence?
  end

  def self.matches_auto_silence_regex?(manager)
    args = manager.args

    pattern = SiteSetting.auto_silence_first_post_regex

    return false if pattern.blank?
    return false unless is_first_post?(manager)

    begin
      regex = Regexp.new(pattern, Regexp::IGNORECASE)
    rescue => e
      Rails.logger.warn "Invalid regex in auto_silence_first_post_regex #{e}"
      return false
    end

    "#{args[:title]} #{args[:raw]}" =~ regex
  end

  def self.exempt_user?(user)
    user.staff?
  end

  def self.post_needs_approval?(manager)
    user = manager.user

    return :email_auth_res_enqueue if manager.args[:email_auth_res_action] == :enqueue

    return :skip if exempt_user?(user)

    return :email_spam if manager.args[:email_spam]

    if (
         user.trust_level <= TrustLevel.levels[:basic] &&
           (user.post_count + user.topic_count) < SiteSetting.approve_post_count
       )
      return :post_count
    end

    if !user.staged? && !user.in_any_groups?(SiteSetting.approve_unless_allowed_groups_map)
      return :group
    end

    if (
         manager.args[:title].present? && !user.staged? &&
           !user.in_any_groups?(SiteSetting.approve_new_topics_unless_allowed_groups_map)
       )
      return :new_topics_unless_allowed_groups
    end

    if WordWatcher.new("#{manager.args[:title]} #{manager.args[:raw]}").requires_approval?
      return :watched_word
    end

    return :fast_typer if is_fast_typer?(manager)

    return :auto_silence_regex if auto_silence?(manager) || matches_auto_silence_regex?(manager)

    return :staged if SiteSetting.approve_unless_staged? && user.staged?

    return :category if post_needs_approval_in_its_category?(manager)

    if (
         manager.args[:image_sizes].present? &&
           !user.in_any_groups?(SiteSetting.skip_review_media_groups_map)
       )
      return :contains_media
    end

    :skip
  end

  def self.post_needs_approval_in_its_category?(manager)
    if manager.args[:topic_id].present?
      cat = Category.joins(:topics).find_by(topics: { id: manager.args[:topic_id] })
      return false unless cat

      topic = Topic.find(manager.args[:topic_id])
      cat.require_reply_approval? && !manager.user.guardian.can_review_topic?(topic)
    elsif manager.args[:category].present?
      cat = Category.find(manager.args[:category])
      cat.require_topic_approval? && !manager.user.guardian.is_category_group_moderator?(cat)
    else
      false
    end
  end

  def self.default_handler(manager)
    reason = post_needs_approval?(manager)
    return if reason == :skip

    validator = PostValidator.new
    post = Post.new(raw: manager.args[:raw])
    post.user = manager.user
    validator.validate(post)

    if post.errors[:raw].present?
      result = NewPostResult.new(:created_post, false)
      result.errors.add(:base, post.errors[:raw])
      return result
    elsif manager.args[:topic_id]
      topic = Topic.unscoped.where(id: manager.args[:topic_id]).first

      unless manager.user.guardian.can_create_post_on_topic?(topic)
        result = NewPostResult.new(:created_post, false)
        result.errors.add(:base, I18n.t(:topic_not_found))
        return result
      end
    elsif manager.args[:category]
      category = Category.find_by(id: manager.args[:category])

      unless manager.user.guardian.can_create_topic_on_category?(category)
        result = NewPostResult.new(:created_post, false)
        result.errors.add(:base, I18n.t("js.errors.reasons.forbidden"))
        return result
      end
    end

    result = manager.enqueue(reason)

    I18n.with_locale(SiteSetting.default_locale) do
      if is_fast_typer?(manager)
        UserSilencer.silence(
          manager.user,
          Discourse.system_user,
          keep_posts: true,
          reason: I18n.t("user.new_user_typed_too_fast"),
        )
      elsif auto_silence?(manager) || matches_auto_silence_regex?(manager)
        UserSilencer.silence(
          manager.user,
          Discourse.system_user,
          keep_posts: true,
          reason: I18n.t("user.content_matches_auto_silence_regex"),
        )
      elsif reason == :email_spam && is_first_post?(manager)
        UserSilencer.silence(
          manager.user,
          Discourse.system_user,
          keep_posts: true,
          reason: I18n.t("user.email_in_spam_header"),
        )
      end
    end

    result
  end

  def self.queue_enabled?
    SiteSetting.approve_post_count > 0 ||
      !(
        SiteSetting.approve_unless_allowed_groups_map.include?(Group::AUTO_GROUPS[:trust_level_0])
      ) ||
      !(
        SiteSetting.approve_new_topics_unless_allowed_groups_map.include?(
          Group::AUTO_GROUPS[:trust_level_0],
        )
      ) || SiteSetting.approve_unless_staged ||
      WordWatcher.words_for_action_exist?(:require_approval) || handlers.size > 1
  end

  def initialize(user, args)
    @user = user
    @args = args.delete_if { |_, v| v.nil? }
  end

  def perform
    if !self.class.exempt_user?(@user) &&
         matches = WordWatcher.new("#{@args[:title]} #{@args[:raw]}").should_block?.presence
      result = NewPostResult.new(:created_post, false)
      if matches.size == 1
        key = "contains_blocked_word"
        translation_args = { word: CGI.escapeHTML(matches[0]) }
      else
        key = "contains_blocked_words"
        translation_args = { words: CGI.escapeHTML(matches.join(", ")) }
      end
      result.errors.add(:base, I18n.t(key, translation_args))
      return result
    end

    # Perform handlers until one returns a result
    NewPostManager.handlers.any? do |handler|
      result = handler.call(self)
      return result if result
    end

    # We never queue private messages
    if @args[:archetype] == Archetype.private_message ||
         (
           args[:topic_id] &&
             Topic.where(id: args[:topic_id], archetype: Archetype.private_message).exists?
         )
      return perform_create_post
    end

    NewPostManager.default_handler(self) || perform_create_post
  end

  # Enqueue this post
  def enqueue(reason = nil, creator_opts: {})
    result = NewPostResult.new(:enqueued)
    payload = { raw: @args[:raw], tags: @args[:tags] }
    %w[typing_duration_msecs composer_open_duration_msecs reply_to_post_number].each do |a|
      payload[a] = @args[a].to_i if @args[a]
    end

    self.class.plugin_payload_attributes.each { |a| payload[a] = @args[a] if @args[a].present? }

    payload[:via_email] = true if !!@args[:via_email]
    payload[:raw_email] = @args[:raw_email] if @args[:raw_email].present?

    reviewable =
      ReviewableQueuedPost.new(
        created_by: Discourse.system_user,
        payload: payload,
        topic_id: @args[:topic_id],
        reviewable_by_moderator: true,
        target_created_by: @user,
      )
    reviewable.payload["title"] = @args[:title] if @args[:title].present?
    reviewable.category_id = args[:category] if args[:category].present?
    reviewable.created_new!

    create_options = reviewable.create_options.merge(creator_opts)

    creator =
      (
        if @args[:topic_id]
          PostCreator.new(@user, create_options)
        else
          TopicCreator.new(@user, Guardian.new(@user), create_options)
        end
      )

    errors = Set.new
    creator.valid?
    creator.errors.full_messages.each { |msg| errors << msg }
    errors = creator.errors.full_messages.uniq
    if errors.blank?
      if reviewable.save
        reviewable.add_score(
          Discourse.system_user,
          ReviewableScore.types[:needs_approval],
          reason: reason,
          force_review: true,
        )
      else
        reviewable.errors.full_messages.each { |msg| errors << msg }
      end
    end

    result.reviewable = reviewable
    result.reason = reason if reason
    result.check_errors(errors)
    result.pending_count = ReviewableQueuedPost.where(target_created_by: @user).pending.count
    result
  end

  def perform_create_post
    result = NewPostResult.new(:create_post)
    creator = PostCreator.new(@user, @args)
    post = creator.create
    result.check_errors_from(creator)

    if result.success?
      result.post = post
    else
      @user.flag_linked_posts_as_spam if creator.spam?
    end

    result
  end
end

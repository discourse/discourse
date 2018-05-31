require_dependency 'post_creator'
require_dependency 'new_post_result'
require_dependency 'post_enqueuer'
require_dependency 'word_watcher'

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

  def self.clear_handlers!
    @sorted_handlers = [{ priority: 0, proc: method(:default_handler) }]
  end

  def self.add_handler(priority = 0, &block)
    sorted_handlers << { priority: priority, proc: block }
    @sorted_handlers.sort_by! { |h| -h[:priority] }
  end

  def self.is_first_post?(manager)
    user = manager.user
    args = manager.args

    !!(
      args[:first_post_checks] &&
      user.post_count == 0
    )
  end

  def self.is_fast_typer?(manager)
    args = manager.args

    is_first_post?(manager) &&
    args[:typing_duration_msecs].to_i < SiteSetting.min_first_post_typing_time &&
    SiteSetting.auto_silence_fast_typers_on_first_post &&
    manager.user.trust_level <= SiteSetting.auto_silence_fast_typers_max_trust_level
  end

  def self.matches_auto_silence_regex?(manager)
    args = manager.args

    pattern = SiteSetting.auto_silence_first_post_regex

    return false unless pattern.present?
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

    return false if exempt_user?(user)

    (user.trust_level <= TrustLevel.levels[:basic] && user.post_count < SiteSetting.approve_post_count) ||
    (user.trust_level < SiteSetting.approve_unless_trust_level.to_i) ||
    (manager.args[:title].present? && user.trust_level < SiteSetting.approve_new_topics_unless_trust_level.to_i) ||
    is_fast_typer?(manager) ||
    matches_auto_silence_regex?(manager) ||
    WordWatcher.new("#{manager.args[:title]} #{manager.args[:raw]}").requires_approval? ||
    (SiteSetting.approve_unless_staged && user.staged)
  end

  def self.default_handler(manager)
    if post_needs_approval?(manager)
      validator = Validators::PostValidator.new
      post = Post.new(raw: manager.args[:raw])
      post.user = manager.user
      validator.validate(post)
      if post.errors[:raw].present?
        result = NewPostResult.new(:created_post, false)
        result.errors[:base] << post.errors[:raw]
        return result
      end

      # Can the user create the post in the first place?
      if manager.args[:topic_id]
        topic = Topic.unscoped.where(id: manager.args[:topic_id]).first

        unless manager.user.guardian.can_create_post_on_topic?(topic)
          result = NewPostResult.new(:created_post, false)
          result.errors[:base] << I18n.t(:topic_not_found)
          return result
        end
      end

      result = manager.enqueue('default')

      if is_fast_typer?(manager)
        UserSilencer.silence(manager.user, Discourse.system_user, keep_posts: true, reason: I18n.t("user.new_user_typed_too_fast"))
      elsif matches_auto_silence_regex?(manager)
        UserSilencer.silence(manager.user, Discourse.system_user, keep_posts: true, reason: I18n.t("user.content_matches_auto_silence_regex"))
      end

      result
    end
  end

  def self.queue_enabled?
    SiteSetting.approve_post_count > 0 ||
    SiteSetting.approve_unless_trust_level.to_i > 0 ||
    SiteSetting.approve_new_topics_unless_trust_level.to_i > 0 ||
    SiteSetting.approve_unless_staged ||
    WordWatcher.words_for_action_exists?(:require_approval) ||
    handlers.size > 1
  end

  def initialize(user, args)
    @user = user
    @args = args.delete_if { |_, v| v.nil? }
  end

  def perform
    if !self.class.exempt_user?(@user) && matches = WordWatcher.new("#{@args[:title]} #{@args[:raw]}").should_block?
      result = NewPostResult.new(:created_post, false)
      result.errors[:base] << I18n.t('contains_blocked_words', word: matches[0])
      return result
    end

    # We never queue private messages
    return perform_create_post if @args[:archetype] == Archetype.private_message

    if args[:topic_id] && Topic.where(id: args[:topic_id], archetype: Archetype.private_message).exists?
      return perform_create_post
    end

    # Perform handlers until one returns a result
    handled = NewPostManager.handlers.any? do |handler|
      result = handler.call(self)
      return result if result

      false
    end

    perform_create_post unless handled
  end

  # Enqueue this post in a queue
  def enqueue(queue, reason = nil)
    result = NewPostResult.new(:enqueued)
    enqueuer = PostEnqueuer.new(@user, queue)

    queued_args = { post_options: @args.dup }
    queued_args[:raw] = queued_args[:post_options].delete(:raw)
    queued_args[:topic_id] = queued_args[:post_options].delete(:topic_id)

    post = enqueuer.enqueue(queued_args)

    QueuedPost.broadcast_new! if post && post.errors.empty?

    result.queued_post = post
    result.reason = reason if reason
    result.check_errors_from(enqueuer)
    result.pending_count = QueuedPost.new_posts.where(user_id: @user.id).count
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

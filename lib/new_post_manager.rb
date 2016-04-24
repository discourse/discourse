require_dependency 'post_creator'
require_dependency 'new_post_result'
require_dependency 'post_enqueuer'
require_dependency 'post_queued_preview_mapper'

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
    sorted_handlers.map {|h| h[:proc]}
  end

  def self.clear_handlers!
    @sorted_handlers = [{ priority: 0, proc: method(:default_handler) }]
  end

  def self.add_handler(priority=0, &block)
    sorted_handlers << { priority: priority, proc: block }
    @sorted_handlers.sort_by! {|h| -h[:priority]}
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
    SiteSetting.auto_block_fast_typers_on_first_post &&
    manager.user.trust_level <= SiteSetting.auto_block_fast_typers_max_trust_level
  end

  def self.matches_auto_block_regex?(manager)
    args = manager.args

    pattern = SiteSetting.auto_block_first_post_regex

    return false unless pattern.present?
    return false unless is_first_post?(manager)

    begin
      regex = Regexp.new(pattern, Regexp::IGNORECASE)
    rescue => e
      Rails.logger.warn "Invalid regex in auto_block_first_post_regex #{e}"
      return false
    end

    "#{args[:title]} #{args[:raw]}" =~ regex

  end

  def self.user_needs_approval?(manager)
    user = manager.user

    return false if user.staff? || user.staged
    return true if queued_preview_enabled?

    (user.trust_level <= TrustLevel.levels[:basic] && user.post_count < SiteSetting.approve_post_count) ||
    (user.trust_level < SiteSetting.approve_unless_trust_level.to_i) ||
    is_fast_typer?(manager) ||
    matches_auto_block_regex?(manager)
  end

  def self.default_handler(manager)
    if user_needs_approval?(manager)

      result = manager.enqueue('default')

      if is_fast_typer?(manager) || matches_auto_block_regex?(manager)
        UserBlocker.block(manager.user, Discourse.system_user, keep_posts: true)
      end

      result
    end
  end

  def self.queue_enabled?
    SiteSetting.approve_post_count > 0 ||
    SiteSetting.approve_unless_trust_level.to_i > 0 ||
    handlers.size > 1 ||
    queued_preview_enabled?
  end

  def self.queued_preview_enabled?
    SiteSetting.queued_preview_mode
  end

  def initialize(user, args)
    @user = user
    @args = args.delete_if {|_, v| v.nil?}
  end

  def perform
    # We never queue private messages
    return perform_create_post if @args[:archetype] == Archetype.private_message
    if args[:topic_id] && Topic.where(id: args[:topic_id], archetype: Archetype.private_message).exists?
      return perform_create_post
    end

    # Perform handlers until one returns true result
    # and remember that result
    handled_result = nil

    handled = NewPostManager.handlers.any? do |handler|
      handled_result = handler.call(self)
    end

    if self.class.queued_preview_enabled?
      if handled && handled_result
        return handled_result if handled_result.failed? || handled_result.action != :enqueued
      end

      create_result = perform_create_post

      if !create_result.present? || create_result.failed?
        # If there is some queued_post - destroy it
        handled_result.queued_post.destroy if handled_result.present? && handled_result.queued_post.present?
        return create_result
      end

      # Do mapping from posts to queued_posts to hide it
      # if queued_preview mode is on
      if create_result.success? && handled_result.present? && handled_result.queued_post.present? && handled_result.success?
        queued_preview(handled_result, create_result)
      end

      create_result

    else

      if handled
        handled_result
      else
        perform_create_post
      end

    end
  end

  # Enqueue this post in a queue
  def enqueue(queue, reason=nil)
    result = NewPostResult.new(:enqueued)
    enqueuer = PostEnqueuer.new(@user, queue)

    queued_args = {post_options: @args.dup}
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

  # Create hiding mapping from posts to queued_posts
  def queued_preview(enqueue_result, post_result)
    PostQueuedPreviewMapper.new(enqueue_result, post_result).hide
  end

end

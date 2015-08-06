require_dependency 'post_creator'
require_dependency 'new_post_result'
require_dependency 'post_enqueuer'

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

    return false if user.staff?

    (user.post_count < SiteSetting.approve_post_count) ||
    (user.trust_level < SiteSetting.approve_unless_trust_level.to_i) ||
    is_fast_typer?(manager) ||
    matches_auto_block_regex?(manager)
  end

  def self.default_handler(manager)
    if user_needs_approval?(manager)

      result = manager.enqueue('default')

      block = is_fast_typer?(manager)

      block ||= matches_auto_block_regex?(manager)

      manager.user.update_columns(blocked: true) if block

      result

    end
  end

  def self.queue_enabled?
    SiteSetting.approve_post_count > 0 ||
    SiteSetting.approve_unless_trust_level.to_i > 0 ||
    handlers.size > 1
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

    # Perform handlers until one returns a result
    handled = NewPostManager.handlers.any? do |handler|
      result = handler.call(self)
      return result if result

      false
    end

    perform_create_post unless handled
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

end

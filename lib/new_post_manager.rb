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

  def self.user_needs_approval?(user)
    return false if user.staff?

    (user.post_count < SiteSetting.approve_post_count) ||
      (user.trust_level < SiteSetting.approve_unless_trust_level.to_i)
  end

  def self.default_handler(manager)
    manager.enqueue('default') if user_needs_approval?(manager.user)
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

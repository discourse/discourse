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

  def self.handlers
    @handlers ||= Set.new
  end

  def self.add_handler(&block)
    handlers << block
  end

  def self.default_handler(manager)
    if (manager.user.post_count < SiteSetting.approve_post_count) ||
       (manager.user.trust_level < SiteSetting.approve_unless_trust_level.to_i)
      return manager.enqueue('default')
    end
  end

  add_handler {|manager| default_handler(manager) }

  def initialize(user, args)
    @user = user
    @args = args.delete_if {|_, v| v.nil?}
  end

  def perform

    # Perform handlers until one returns a result
    handled = NewPostManager.handlers.any? do |handler|
      result = handler.call(self)
      return result if result

      false
    end

    perform_create_post unless handled
  end

  # Enqueue this post in a queue
  def enqueue(queue)
    result = NewPostResult.new(:enqueued)
    enqueuer = PostEnqueuer.new(@user, queue)

    queued_args = {post_options: @args.dup}
    queued_args[:raw] = queued_args[:post_options].delete(:raw)
    queued_args[:topic_id] = queued_args[:post_options].delete(:topic_id)

    post = enqueuer.enqueue(queued_args)

    QueuedPost.broadcast_new! if post && post.errors.empty?

    result.queued_post = post
    result.check_errors_from(enqueuer)
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

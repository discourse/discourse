require_dependency 'topic_creator'
require_dependency 'queued_post'
require_dependency 'has_errors'

class PostEnqueuer
  include HasErrors

  def initialize(user, queue)
    @user = user
    @queue = queue
  end

  def enqueue(args)
    queued_post = QueuedPost.new(queue: @queue,
                                 state: QueuedPost.states[:new],
                                 user_id: @user.id,
                                 topic_id: args[:topic_id],
                                 raw: args[:raw],
                                 post_options: args[:post_options] || {})

    validate_method = :"validate_#{@queue}"
    if respond_to?(validate_method)
      return unless send(validate_method, queued_post.create_options)
    end

    if queued_post.save
      queued_post.create_pending_action
    else
      add_errors_from(queued_post)
    end

    queued_post
  end

  def validate_new_topic(create_options)
    topic_creator = TopicCreator.new(@user, Guardian.new(@user), create_options)
    validate_child(topic_creator)
  end

  def validate_new_post(create_options)
    post_creator = PostCreator.new(@user, create_options)
    validate_child(post_creator)
  end

end

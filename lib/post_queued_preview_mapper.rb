require_dependency 'queued_preview_post_map'
require_dependency 'has_errors'

class PostQueuedPreviewMapper
  include HasErrors

  def initialize(enqueue_result, post_result)
    @queue = enqueue_result
    @post = post_result
  end

  def hide
    # topic_id is null for old topic, id for new topic
    mapping = QueuedPreviewPostMap.new(
      queued_id: @queue.queued_post.id,
      post_id: @post.post.id,
      topic_id: @queue.queued_post.topic_id ? nil : @post.post.topic_id
    )
    add_errors_from(mapping) unless mapping.save

    mapping
  end

end

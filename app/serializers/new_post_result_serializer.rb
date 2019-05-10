require_dependency 'application_serializer'

class NewPostResultSerializer < ApplicationSerializer
  attributes :action,
             :post,
             :errors,
             :success,
             :pending_count,
             :reason

  has_one :pending_post, serializer: TopicPendingPostSerializer, root: false, embed: :objects

  def post
    post_serializer = PostSerializer.new(object.post, scope: scope, root: false)
    post_serializer.draft_sequence = DraftSequence.current(scope.user, object.post.topic.draft_key)
    post_serializer.as_json
  end

  def include_post?
    object.post.present?
  end

  def success
    true
  end

  def include_success?
    @object.success?
  end

  def errors
    object.errors.full_messages
  end

  def include_errors?
    !object.errors.empty?
  end

  def reason
    object.reason
  end

  def include_reason?
    scope.is_staff? && reason.present?
  end

  def action
    object.action
  end

  def pending_count
    object.pending_count
  end

  def pending_post
    object.reviewable
  end

  def include_pending_post?
    object.reviewable.present?
  end

  def include_pending_count?
    pending_count.present?
  end

end

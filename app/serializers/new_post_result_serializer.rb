require_dependency 'application_serializer'

class NewPostResultSerializer < ApplicationSerializer
  attributes :action,
             :post,
             :errors,
             :success

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

  def action
    object.action
  end

end

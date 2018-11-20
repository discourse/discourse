class WebHookFlagSerializer < ApplicationSerializer
  attributes :id,
             :post,
             :flag_type,
             :created_by,
             :created_at,
             :resolved_at,
             :resolved_by

  def post
    WebHookPostSerializer.new(object.post, scope: scope, root: false).as_json
  end

  def flag_type
    object.post_action_type_key
  end

  def include_post?
    object.post.present?
  end

  def created_by
    object.user && object.user.username
  end

  def resolved_at
    object.disposed_at
  end

  def include_resolved_at?
    object.disposed_at.present?
  end

  def resolved_by
    User.find(object.disposed_by_id).username
  end

  def include_resolved_by?
    object.disposed_by_id.present?
  end
end

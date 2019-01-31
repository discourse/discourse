class Admin::ModerationHistoryController < Admin::AdminController

  def index
    history_filter = params[:filter]
    raise Discourse::NotFound unless ['post', 'topic'].include?(history_filter)

    query = UserHistory.where(
      action: UserHistory.actions.only(
        :delete_user,
        :suspend_user,
        :silence_user,
        :delete_post,
        :delete_topic,
        :post_approved,
      ).values
    )

    case history_filter
    when 'post'
      raise Discourse::NotFound if params[:post_id].blank?
      query = query.where(post_id: params[:post_id])
    when 'topic'
      raise Discourse::NotFound if params[:topic_id].blank?
      query = query.where(
        "topic_id = ? OR post_id IN (?)",
        params[:topic_id],
        Post.with_deleted.where(topic_id: params[:topic_id]).pluck(:id)
      )
    end
    query = query.includes(:acting_user)
    query = query.order(:created_at)

    render_serialized(
      query,
      UserHistorySerializer,
      root: 'moderation_history',
      rest_serializer: true
    )
  end

end

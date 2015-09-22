class AdminPostSerializer < ApplicationSerializer

  attributes :id,
             :created_at,
             :post_number,
             :name, :username, :avatar_template,
             :topic_id, :topic_slug, :topic_title,
             :category_id,
             :excerpt,
             :hidden,
             :moderator_action,
             :deleted_at, :deleted_by,
             :reply_to_post_number,
             :action_type

  def name
    object.user.name
  end

  def include_name?
    SiteSetting.enable_names?
  end

  def username
    object.user.username
  end

  def avatar_template
    object.user.avatar_template
  end

  def topic_slug
    topic.slug
  end

  def topic_title
    topic.title
  end

  def category_id
    topic.category_id
  end

  def moderator_action
    object.post_type == Post.types[:moderator_action] || object.post_type == Post.types[:small_action]
  end

  def deleted_by
    BasicUserSerializer.new(object.deleted_by, root: false).as_json
  end

  def include_deleted_by?
    object.trashed?
  end

  def action_type
    object.user_actions.select { |ua| ua.user_id = object.user_id }
                       .select { |ua| [UserAction::REPLY, UserAction::RESPONSE].include? ua.action_type }
                       .first.try(:action_type)
  end

  private

    # we need this to handle deleted topics which aren't loaded via the .includes(:topic)
    # because Rails 4 "unscoped" support is bugged (cf. https://github.com/rails/rails/issues/13775)
    def topic
      return @topic if @topic
      @topic = object.topic || Topic.with_deleted.find(object.topic_id)
      @topic
    end

end

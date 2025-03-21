# frozen_string_literal: true

class TopicListItemSerializer < ListableTopicSerializer
  include TopicTagsMixin

  attributes :views,
             :like_count,
             :has_summary,
             :archetype,
             :last_poster_username,
             :category_id,
             :op_like_count,
             :op_can_like,
             :op_liked,
             :first_post_id,
             :pinned_globally,
             :liked_post_numbers,
             :featured_link,
             :featured_link_root_domain,
             :allowed_user_count,
             :participant_groups,
             :is_hot

  has_many :posters, serializer: TopicPosterSerializer, embed: :objects
  has_many :participants, serializer: TopicPosterSerializer, embed: :objects

  def include_participant_groups?
    object.private_message?
  end

  def posters
    object.posters || object.posters_summary || []
  end

  def op_like_count
    object.first_post && object.first_post.like_count
  end

  def include_op_can_like?
    serialize_topic_op_likes_data_enabled?
  end

  def op_can_like
    return false if !scope.user || !object.first_post

    first_post = object.first_post
    return false if first_post.user_id == scope.user.id
    return false unless scope.post_can_act?(first_post, :like)

    first_post_liked =
      PostAction.where(
        user_id: scope.user.id,
        post_id: first_post.id,
        post_action_type_id: PostActionType.types[:like],
      ).first
    return scope.can_delete?(first_post_liked) if first_post_liked

    true
  end

  def include_op_liked?
    serialize_topic_op_likes_data_enabled?
  end

  def op_liked
    return false if !scope.user || !object.first_post

    PostAction.where(
      user_id: scope.user.id,
      post_id: object.first_post.id,
      post_action_type_id: PostActionType.types[:like],
    ).exists?
  end

  def include_first_post_id?
    serialize_topic_op_likes_data_enabled?
  end

  def first_post_id
    return false if !object.first_post
    object.first_post.id
  end

  def last_poster_username
    posters.find { |poster| poster.user.id == object.last_post_user_id }.try(:user).try(:username)
  end

  def category_id
    # If it's a shared draft, show the destination topic instead
    if object.includes_destination_category && object.shared_draft
      return object.shared_draft.category_id
    end

    object.category_id
  end

  def participants
    object.participants_summary || []
  end

  def participant_groups
    object.participant_groups_summary || []
  end

  def include_liked_post_numbers?
    include_post_action? :like
  end

  def include_post_action?(action)
    object.user_data && object.user_data.post_action_data &&
      object.user_data.post_action_data.key?(PostActionType.types[action])
  end

  def liked_post_numbers
    object.user_data.post_action_data[PostActionType.types[:like]]
  end

  def include_participants?
    object.private_message?
  end

  def include_op_like_count?
    # PERF: long term we probably want a cheaper way of looking stuff up
    # this is rather odd code, but we need to have op_likes loaded somehow
    # simplest optimisation is adding a cache column on topic.
    object.association(:first_post).loaded?
  end

  def include_featured_link?
    SiteSetting.topic_featured_link_enabled
  end

  def include_featured_link_root_domain?
    SiteSetting.topic_featured_link_enabled && object.featured_link.present?
  end

  def allowed_user_count
    # Don't use count as it will result in a query
    object.allowed_users.length
  end

  def include_allowed_user_count?
    object.private_message?
  end

  def is_hot
    TopicHotScore.hottest_topic_ids.include?(object.id)
  end

  def include_is_hot?
    theme_enabled = theme_modifier_helper.serialize_topic_is_hot
    plugin_enabled = DiscoursePluginRegistry.apply_modifier(:serialize_topic_is_hot, false)

    theme_enabled || plugin_enabled
  end

  private

  def serialize_topic_op_likes_data_enabled?
    theme_enabled = theme_modifier_helper.serialize_topic_op_likes_data
    plugin_enabled = DiscoursePluginRegistry.apply_modifier(:serialize_topic_op_likes_data, false)

    theme_enabled || plugin_enabled
  end

  def theme_modifier_helper
    @theme_modifier_helper ||= ThemeModifierHelper.new(request: scope.request)
  end
end

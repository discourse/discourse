class TopicListItemSerializer < ListableTopicSerializer
  include TopicTagsMixin

  attributes :views,
             :like_count,
             :has_summary,
             :archetype,
             :last_poster_username,
             :category_id,
             :op_like_count,
             :pinned_globally,
             :bookmarked_post_numbers,
             :liked_post_numbers,
             :featured_link,
             :featured_link_root_domain

  has_many :posters, serializer: TopicPosterSerializer, embed: :objects
  has_many :participants, serializer: TopicPosterSerializer, embed: :objects

  def posters
    object.posters || []
  end

  def op_like_count
    object.first_post && object.first_post.like_count
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

  def include_bookmarked_post_numbers?
    include_post_action? :bookmark
  end

  def include_liked_post_numbers?
    include_post_action? :like
  end

  def include_post_action?(action)
    object.user_data &&
      object.user_data.post_action_data &&
      object.user_data.post_action_data.key?(PostActionType.types[action])
  end

  def liked_post_numbers
    object.user_data.post_action_data[PostActionType.types[:like]]
  end

  def bookmarked_post_numbers
    object.user_data.post_action_data[PostActionType.types[:bookmark]]
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

end

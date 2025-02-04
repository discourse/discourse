# frozen_string_literal: true

class WebHookPostSerializer < PostSerializer
  attributes :topic_posts_count, :topic_filtered_posts_count, :topic_archetype, :category_slug

  def include_topic_title?
    true
  end

  def include_raw?
    true
  end

  def include_category_id?
    true
  end

  %i[
    can_view
    can_edit
    can_delete
    can_recover
    can_see_hidden_post
    can_wiki
    actions_summary
    can_view_edit_history
    yours
    flair_url
    flair_bg_color
    flair_color
    notice
    mentioned_users
    badges_granted
  ].each { |attr| define_method("include_#{attr}?") { false } }

  def topic_posts
    @topic_posts ||= object.topic.posts.where(user_deleted: false)
  end

  def topic_posts_count
    object.topic ? topic_posts.count : 0
  end

  def topic_filtered_posts_count
    object.topic ? topic_posts.where(post_type: Post.types[:regular]).count : 0
  end

  def topic_archetype
    object.topic ? object.topic.archetype : ""
  end

  def include_category_slug?
    object.topic && object.topic.category
  end

  def category_slug
    object.topic && object.topic.category ? object.topic.category.slug_for_url : ""
  end

  def include_readers_count?
    false
  end
end

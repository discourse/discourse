require_relative 'post_item_excerpt'

class DraftSerializer < ApplicationSerializer
  include PostItemExcerpt

  attributes :created_at,
             :draft_key,
             :sequence,
             :draft_username,
             :avatar_template,
             :data,
             :topic_id,
             :username,
             :username_lower,
             :name,
             :user_id,
             :title,
             :slug,
             :category_id,
             :closed,
             :archetype,
             :archived

  def avatar_template
    User.avatar_template(object.username, object.uploaded_avatar_id)
  end

  def slug
    Slug.for(object.title)
  end

  def include_slug?
    object.title.present?
  end

  def closed
    object.topic_closed
  end

  def archived
    object.topic_archived
  end

  def include_closed?
    object.topic_closed.present?
  end

  def include_archived?
    object.topic_archived.present?
  end

  def include_category_id?
    object.category_id.present?
  end

end

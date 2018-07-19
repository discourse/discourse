class DraftSerializer < ApplicationSerializer

  attributes :created_at,
             :draft_key,
             :sequence,
             :avatar_template,
             :slug,
             :data,
             :topic_id,
             :username,
             :name,
             :user_id,
             :title,
             :category_id,
             :closed,
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

  def include_slug?
    object.title.present?
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

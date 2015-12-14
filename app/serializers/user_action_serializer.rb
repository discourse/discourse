class UserActionSerializer < ApplicationSerializer

  attributes :action_type,
             :created_at,
             :excerpt,
             :avatar_template,
             :acting_avatar_template,
             :slug,
             :topic_id,
             :target_user_id,
             :target_name,
             :target_username,
             :post_number,
             :post_id,
             :reply_to_post_number,
             :username,
             :name,
             :user_id,
             :acting_username,
             :acting_name,
             :acting_user_id,
             :title,
             :deleted,
             :hidden,
             :post_type,
             :action_code,
             :edit_reason,
             :category_id,
             :closed,
             :archived

  def excerpt
    cooked = object.cooked || PrettyText.cook(object.raw)
    PrettyText.excerpt(cooked, 300, keep_emoji_images: true) if cooked
  end

  def avatar_template
    User.avatar_template(object.username, object.uploaded_avatar_id)
  end

  def acting_avatar_template
    User.avatar_template(object.acting_username, object.acting_uploaded_avatar_id)
  end

  def include_acting_avatar_template?
    object.acting_username.present?
  end

  def include_name?
    SiteSetting.enable_names?
  end

  def include_target_name?
    include_name?
  end

  def include_acting_name?
    include_name?
  end

  def slug
    Slug.for(object.title)
  end

  def include_slug?
    object.title.present?
  end

  def include_reply_to_post_number?
    object.action_type == UserAction::REPLY
  end

  def include_edit_reason?
    object.action_type == UserAction::EDIT
  end

  def closed
    object.topic_closed
  end

  def archived
    object.topic_archived
  end

end

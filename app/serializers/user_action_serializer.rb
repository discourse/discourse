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
             :moderator_action

  def excerpt
    PrettyText.excerpt(object.cooked,300) if object.cooked
  end

  def avatar_template
    user = User.new
    user[:email] = object.email
    user[:use_uploaded_avatar] = object.use_uploaded_avatar
    user[:uploaded_avatar_template] = object.uploaded_avatar_template
    user[:uploaded_avatar_id] = object.uploaded_avatar_id
    user.avatar_template
  end

  def acting_avatar_template
    acting_user = User.new
    acting_user[:email] = object.acting_email
    acting_user[:use_uploaded_avatar] = object.acting_use_uploaded_avatar
    acting_user[:uploaded_avatar_template] = object.acting_uploaded_avatar_template
    acting_user[:uploaded_avatar_id] = object.acting_uploaded_avatar_id
    acting_user.avatar_template
  end

  def slug
    Slug.for(object.title)
  end

  def moderator_action
    object.post_type == Post.types[:moderator_action]
  end

end

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
    avatar_for(
      object.email,
      object.use_uploaded_avatar,
      object.uploaded_avatar_template,
      object.uploaded_avatar_id
    )
  end

  def acting_avatar_template
    avatar_for(
                object.acting_email,
                object.acting_use_uploaded_avatar,
                object.acting_uploaded_avatar_template,
                object.acting_uploaded_avatar_id
    )
  end

  def slug
    Slug.for(object.title)
  end

  def moderator_action
    object.post_type == Post.types[:moderator_action]
  end

  private
  def avatar_for(email, use_uploaded_avatar, uploaded_avatar_template, uploaded_avatar_id)
    # NOTE: id is required for cases where the template is blank (during initial population)
    User.new(
      email: email,
      use_uploaded_avatar: use_uploaded_avatar,
      uploaded_avatar_template: uploaded_avatar_template,
      uploaded_avatar_id: uploaded_avatar_id
    ).avatar_template
  end

end

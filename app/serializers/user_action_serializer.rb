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
             :hidden


  def excerpt
    PrettyText.excerpt(object.cooked,300) if object.cooked
  end

  def avatar_template
    User.avatar_template(object.email)
  end

  def acting_avatar_template
    User.avatar_template(object.acting_email)
  end

  def slug
    Slug.for(object.title)
  end

end

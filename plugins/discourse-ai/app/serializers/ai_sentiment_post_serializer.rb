# frozen_string_literal: true

class AiSentimentPostSerializer < ApplicationSerializer
  attributes :post_id,
             :topic_id,
             :topic_title,
             :post_number,
             :username,
             :name,
             :avatar_template,
             :excerpt,
             :sentiment,
             :truncated,
             :category_id,
             :created_at

  def avatar_template
    User.avatar_template(object.username, object.uploaded_avatar_id)
  end

  def excerpt
    Post.excerpt(object.post_cooked)
  end

  def truncated
    object.post_cooked.length > SiteSetting.post_excerpt_maxlength
  end
end

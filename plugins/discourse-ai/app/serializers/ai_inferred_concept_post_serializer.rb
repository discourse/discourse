# frozen_string_literal: true

class AiInferredConceptPostSerializer < ApplicationSerializer
  attributes :id,
             :post_number,
             :topic_id,
             :topic_title,
             :username,
             :avatar_template,
             :created_at,
             :updated_at,
             :excerpt,
             :truncated,
             :inferred_concepts

  def avatar_template
    User.avatar_template(object.username, object.uploaded_avatar_id)
  end

  def excerpt
    Post.excerpt(object.cooked)
  end

  def truncated
    object.cooked.length > SiteSetting.post_excerpt_maxlength
  end

  def inferred_concepts
    ActiveModel::ArraySerializer.new(
      object.inferred_concepts,
      each_serializer: InferredConceptSerializer,
    )
  end
end

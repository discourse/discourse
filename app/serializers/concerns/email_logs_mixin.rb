# frozen_string_literal: true

module EmailLogsMixin
  def self.included(klass)
    klass.attributes :id,
      :to_address,
      :email_type,
      :user_id,
      :created_at,
      :post_url,
      :post_description

    klass.has_one :user, serializer: BasicUserSerializer, embed: :objects
  end

  def post_url
    object.post.url
  end

  def include_post_url?
    object.post.present?
  end

  def include_post_description?
    object.post.present? && object.post.topic.present?
  end

  def post_description
    "#{object.post.topic.title} ##{object.post.post_number}"
  end
end

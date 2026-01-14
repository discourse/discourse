# frozen_string_literal: true

class DiscourseSolved::SolvedPostSerializer < ApplicationSerializer
  attributes :created_at,
             :archived,
             :avatar_template,
             :category_id,
             :closed,
             :cooked,
             :excerpt,
             :name,
             :post_id,
             :post_number,
             :post_type,
             :raw,
             :slug,
             :topic_id,
             :topic_title,
             :truncated,
             :url,
             :user_id,
             :username

  def archived
    object.topic.archived
  end

  def avatar_template
    object.user&.avatar_template
  end

  def category_id
    object.topic.category_id
  end

  def closed
    object.topic.closed
  end

  def excerpt
    @excerpt ||= PrettyText.excerpt(cooked, 300, keep_emoji_images: true)
  end

  def name
    object.user&.name
  end

  def include_name?
    SiteSetting.enable_names?
  end

  def post_id
    object.id
  end

  def slug
    Slug.for(object.topic.title)
  end

  def include_slug?
    object.topic.title.present?
  end

  def topic_title
    object.topic.title
  end

  def truncated
    true
  end

  def include_truncated?
    cooked.length > 300
  end

  def url
    "#{Discourse.base_url}#{object.url}"
  end

  def user_id
    object.user_id
  end

  def username
    object.user&.username
  end
end

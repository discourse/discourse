# frozen_string_literal: true

class PermalinkSerializer < ApplicationSerializer
  attributes :id,
             :url,
             :topic_id,
             :topic_title,
             :topic_url,
             :post_id,
             :post_url,
             :post_number,
             :post_topic_title,
             :category_id,
             :category_name,
             :category_url,
             :external_url,
             :tag_id,
             :tag_name,
             :tag_url,
             :user_id,
             :user_url,
             :username

  def topic_title
    object&.topic&.title
  end

  def topic_url
    object&.topic&.url
  end

  def post_url
    # use `full_url` to support subfolder setups
    object&.post&.full_url
  end

  def post_number
    object&.post&.post_number
  end

  def post_topic_title
    object&.post&.topic&.title
  end

  def category_name
    object&.category&.name
  end

  def category_url
    object&.category&.url
  end

  def tag_name
    object&.tag&.name
  end

  def tag_url
    object&.tag&.full_url
  end

  def user_url
    object&.user&.full_url
  end

  def username
    object&.user&.username
  end
end

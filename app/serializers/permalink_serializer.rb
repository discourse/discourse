class PermalinkSerializer < ApplicationSerializer
  attributes :id, :url, :topic_id, :topic_title, :topic_url,
             :post_id, :post_url, :post_number, :post_topic_title,
             :category_id, :category_name, :category_url, :external_url

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
end

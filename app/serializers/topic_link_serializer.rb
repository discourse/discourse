class TopicLinkSerializer < ApplicationSerializer

  attributes :url,
             :title,
             :fancy_title,
             :internal,
             :reflection,
             :clicks,
             :user_id

  def url
    object['url']
  end

  def title
    object['title']
  end

  def fancy_title
    object['fancy_title']
  end

  def internal
    object['internal'] == 't'
  end

  def reflection
    object['reflection'] == 't'
  end

  def clicks
    object['clicks'].to_i
  end

  def user_id
    object['user_id'].to_i
  end

  def include_user_id?
    object['user_id'].present?
  end

end

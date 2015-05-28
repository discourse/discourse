class TopicLinkSerializer < ApplicationSerializer

  attributes :url,
             :title,
             :fancy_title,
             :internal,
             :attachment,
             :reflection,
             :clicks,
             :user_id,
             :domain

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

  def attachment
    Discourse.store.has_been_uploaded?(object['url'])
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

  def domain
    object['domain']
  end

end

require_dependency 'discourse'
require 'ipaddr'

class TopicLinkClick < ActiveRecord::Base
  belongs_to :topic_link, counter_cache: :clicks
  belongs_to :user

  has_ip_address :ip

  validates_presence_of :topic_link_id
  validates_presence_of :ip

  # Create a click from a URL and post_id
  def self.create_from(args={})

    # Find the forum topic link
    link = TopicLink.select(:id).where(url: args[:url])
    link = link.where("user_id <> ?", args[:user_id]) if args[:user_id].present?
    link = link.where(post_id: args[:post_id]) if args[:post_id].present?

    # If we don't have a post, just find the first occurance of the link
    link = link.where(topic_id: args[:topic_id]) if args[:topic_id].present?
    link = link.first

    return unless link.present?

    # Rate limit the click counts to once in 24 hours
    rate_key = "link-clicks:#{link.id}:#{args[:user_id] || args[:ip]}"
    if $redis.setnx(rate_key, "1")
      $redis.expire(rate_key, 1.day.to_i)
      create!(topic_link_id: link.id, user_id: args[:user_id], ip: args[:ip])
    end

    args[:url]
  end

  def self.counts_for(topic, posts)
    return {} if posts.blank?
    links = TopicLink
              .includes(:link_topic)
              .where(topic_id: topic.id, post_id: posts.map(&:id))
              .order('reflection asc, clicks desc')

    result = {}
    links.each do |l|
      result[l.post_id] ||= []
      result[l.post_id] << {url: l.url,
                            clicks: l.clicks,
                            title: l.link_topic.try(:title),
                            internal: l.internal,
                            reflection: l.reflection}
    end

    result
  end
end

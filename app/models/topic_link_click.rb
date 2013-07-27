require_dependency 'discourse'
require 'ipaddr'

class TopicLinkClick < ActiveRecord::Base
  belongs_to :topic_link, counter_cache: :clicks
  belongs_to :user

  validates_presence_of :topic_link_id
  validates_presence_of :ip_address

  # Create a click from a URL and post_id
  def self.create_from(args={})

    # Find the forum topic link
    link = TopicLink.select([:id, :user_id]).where(url: args[:url])
    link = link.where(post_id: args[:post_id]) if args[:post_id].present?

    # If we don't have a post, just find the first occurance of the link
    link = link.where(topic_id: args[:topic_id]) if args[:topic_id].present?
    link = link.first

    # If no link is found, return the url for relative links
    unless link.present?
      return args[:url] if args[:url] =~ /^\//
      return nil
    end

    return args[:url] if (args[:user_id] && (link.user_id == args[:user_id]))


    # Rate limit the click counts to once in 24 hours
    rate_key = "link-clicks:#{link.id}:#{args[:user_id] || args[:ip]}"
    if $redis.setnx(rate_key, "1")
      $redis.expire(rate_key, 1.day.to_i)
      create!(topic_link_id: link.id, user_id: args[:user_id], ip_address: args[:ip])
    end

    args[:url]
  end

end

# == Schema Information
#
# Table name: topic_link_clicks
#
#  id            :integer          not null, primary key
#  topic_link_id :integer          not null
#  user_id       :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  ip_address    :string           not null
#
# Indexes
#
#  index_forum_thread_link_clicks_on_forum_thread_link_id  (topic_link_id)
#


require_dependency 'discourse'
require 'ipaddr'
require 'url_helper'

class TopicLinkClickHelper
  include UrlHelper
end

class TopicLinkClick < ActiveRecord::Base
  belongs_to :topic_link, counter_cache: :clicks
  belongs_to :user

  validates_presence_of :topic_link_id
  validates_presence_of :ip_address

  # Create a click from a URL and post_id
  def self.create_from(args={})
    url = args[:url]
    return nil if url.blank?

    helper = TopicLinkClickHelper.new
    uri = URI.parse(url) rescue nil

    urls = Set.new
    urls << url
    if url =~ /^http/
      urls << url.sub(/^https/, 'http')
      urls << url.sub(/^http:/, 'https:')
      urls << helper.schemaless(url)
    end
    urls << helper.absolute_without_cdn(url)
    urls << uri.path if uri.try(:host) == Discourse.current_hostname
    urls << url.sub(/\?.*$/, '') if url.include?('?')

    link = TopicLink.select([:id, :user_id])

    # test for all possible URLs
    link = link.where(Array.new(urls.count, "url = ?").join(" OR "), *urls)

    # Find the forum topic link
    link = link.where(post_id: args[:post_id]) if args[:post_id].present?

    # If we don't have a post, just find the first occurance of the link
    link = link.where(topic_id: args[:topic_id]) if args[:topic_id].present?
    link = link.first

    # If no link is found...
    unless link.present?
      # ... return the url for relative links or when using the same host
      return url if url =~ /^\// || uri.try(:host) == Discourse.current_hostname

      # If we have it somewhere else on the site, just allow the redirect.
      # This is likely due to a onebox of another topic.
      link = TopicLink.find_by(url: url)
      return link.present? ? link.url : nil
    end

    return url if args[:user_id] && link.user_id == args[:user_id]

    # Rate limit the click counts to once in 24 hours
    rate_key = "link-clicks:#{link.id}:#{args[:user_id] || args[:ip]}"
    if $redis.setnx(rate_key, "1")
      $redis.expire(rate_key, 1.day.to_i)
      create!(topic_link_id: link.id, user_id: args[:user_id], ip_address: args[:ip])
    end

    url
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
#  ip_address    :inet             not null
#
# Indexes
#
#  by_link  (topic_link_id)
#

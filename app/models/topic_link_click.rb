require_dependency 'discourse'
require 'ipaddr'
require 'url_helper'

class TopicLinkClick < ActiveRecord::Base
  belongs_to :topic_link, counter_cache: :clicks
  belongs_to :user

  validates_presence_of :topic_link_id

  WHITELISTED_REDIRECT_HOSTNAMES = Set.new(%W{www.youtube.com youtu.be})

  # Create a click from a URL and post_id
  def self.create_from(args = {})
    url = args[:url][0...TopicLink.max_url_length]
    return nil if url.blank?

    uri = UrlHelper.relaxed_parse(url)
    urls = Set.new
    urls << url
    if url =~ /^http/
      urls << url.sub(/^https/, 'http')
      urls << url.sub(/^http:/, 'https:')
      urls << UrlHelper.schemaless(url)
    end
    urls << UrlHelper.absolute_without_cdn(url)
    urls << uri.path if uri.try(:host) == Discourse.current_hostname

    query = url.index('?')
    unless query.nil?
      endpos = url.index('#') || url.size
      urls << url[0..query - 1] + url[endpos..-1]
    end

    # link can have query params, and analytics can add more to the end:
    i = url.length
    while i = url.rindex('&', i - 1)
      urls << url[0...i]
    end

    # add a cdn link
    if uri
      if Discourse.asset_host.present?
        cdn_uri = begin
          URI.parse(Discourse.asset_host)
        rescue URI::Error
        end

        if cdn_uri && cdn_uri.hostname == uri.hostname && uri.path.starts_with?(cdn_uri.path)
          is_cdn_link = true
          urls << uri.path[cdn_uri.path.length..-1]
        end
      end

      if SiteSetting.Upload.s3_cdn_url.present?
        cdn_uri = begin
          URI.parse(SiteSetting.Upload.s3_cdn_url)
        rescue URI::Error
        end

        if cdn_uri && cdn_uri.hostname == uri.hostname && uri.path.starts_with?(cdn_uri.path)
          is_cdn_link = true
          path = uri.path[cdn_uri.path.length..-1]
          urls << path
          urls << "#{Discourse.store.absolute_base_url}#{path}"
        end
      end
    end

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
      return url if url =~ /^\/[^\/]/ || uri.try(:host) == Discourse.current_hostname

      # If we have it somewhere else on the site, just allow the redirect.
      # This is likely due to a onebox of another topic.
      link = TopicLink.find_by(url: url)
      return link.url if link.present?

      return nil unless uri

      # Only redirect to whitelisted hostnames
      return url if WHITELISTED_REDIRECT_HOSTNAMES.include?(uri.hostname) || is_cdn_link

      return nil
    end

    return url if args[:user_id] && link.user_id == args[:user_id]

    # Rate limit the click counts to once in 24 hours
    rate_key = "link-clicks:#{link.id}:#{args[:user_id] || args[:ip]}"
    if $redis.setnx(rate_key, "1")
      $redis.expire(rate_key, 1.day.to_i)
      args[:ip] = nil if args[:user_id]
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
#  ip_address    :inet
#
# Indexes
#
#  by_link  (topic_link_id)
#

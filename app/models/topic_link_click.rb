require_dependency 'discourse'
require 'ipaddr'

class TopicLinkClick < ActiveRecord::Base
  belongs_to :topic_link, counter_cache: :clicks
  belongs_to :user

  validates_presence_of :topic_link_id
  validates_presence_of :ip_address

  def self.recheck_before_date
    DateTime.iso8601('2015-02-01T00:00:00+00:00')
  end

  # Create a click from a URL and post_id
  def self.create_from(args={})

    link = link_query(args).first

    # Prefer to count the link in the post being quoted, if possible
    if link.present? && link.from_quote
      args.delete[:post_id]
      link = link_query(args).first
    end

    # If a post is specified but the link isn't found...
    if !link.present? && args[:post_id].present?
      # Recheck the post with the new extractor
      post = Post.find(args[:post_id])
      # But only if it hasn't been rechecked
      if post && post.baked_at < recheck_before_date
        TopicLink.extract_from(post)
        post.touch(:baked_at) # don't check again
      end
    end

    # If no link is found, allow without tracking for in-forum links
    unless link.present?
      return args[:url] if args[:url] =~ /^\//

      begin
        uri = URI.parse(args[:url])
        return args[:url] if uri.host == URI.parse(Discourse.base_url).host
      rescue
      end

      # If we have it somewhere else on the site, just allow the redirect. This is
      # likely due to a onebox of another topic.
      link = TopicLink.find_by(url: args[:url])
      return link.present? ? link.url : nil
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

  private

  def self.link_query(args)
    # If the URL is absolute, allow HTTPS and HTTP versions of it
    if args[:url] =~ /^http/
      http_url = args[:url].sub(/^https/, 'http')
      https_url = args[:url].sub(/^http\:/, 'https:')
      link = TopicLink.select([:id, :user_id, :from_quote]).where('url = ? OR url = ?', http_url, https_url)
    else
      link = TopicLink.select([:id, :user_id, :from_quote]).where(url: args[:url])
    end

    # Find the forum topic link
    link = link.where(post_id: args[:post_id]) if args[:post_id].present?

    # If we don't have a post, just find the first occurrence of the link
    link = link.where(topic_id: args[:topic_id]) if args[:topic_id].present?

    link
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

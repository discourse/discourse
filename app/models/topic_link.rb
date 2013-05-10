require 'uri'
require_dependency 'slug'

class TopicLink < ActiveRecord::Base
  belongs_to :topic
  belongs_to :user
  belongs_to :post
  belongs_to :link_topic, class_name: 'Topic'

  validates_presence_of :url

  validates_length_of :url, maximum: 500

  validates_uniqueness_of :url, scope: [:topic_id, :post_id]

  has_many :topic_link_clicks

  validate :link_to_self

  # Make sure a topic can't link to itself
  def link_to_self
    errors.add(:base, "can't link to the same topic") if (topic_id == link_topic_id)
  end

  # Extract any urls in body
  def self.extract_from(post)
    return unless post.present?

    TopicLink.transaction do

      added_urls = []
      reflected_urls = []

      PrettyText
        .extract_links(post.cooked)
        .map{|u| [u, URI.parse(u)] rescue nil}
        .reject{|u,p| p.nil?}
        .uniq{|u,p| u}
        .each do |url, parsed|
        begin

          internal = false
          topic_id = nil
          post_number = nil
          if parsed.host == Discourse.current_hostname || !parsed.host
            internal = true

            route = Rails.application.routes.recognize_path(parsed.path)

            # We aren't interested in tracking internal links to users
            next if route[:controller] == 'users'

            topic_id = route[:topic_id]
            post_number = route[:post_number] || 1

            # Store the canonical URL
            topic = Topic.where(id: topic_id).first

            if topic.present?
              url = "#{Discourse.base_url}#{topic.relative_url}"
              url << "/#{post_number}" if post_number.to_i > 1
            end

          end

          # Skip linking to ourselves
          next if topic_id == post.topic_id

          added_urls << url
          TopicLink.create(post_id: post.id,
                           user_id: post.user_id,
                           topic_id: post.topic_id,
                           url: url,
                           domain: parsed.host || Discourse.current_hostname,
                           internal: internal,
                           link_topic_id: topic_id)

          # Create the reflection if we can
          if topic_id.present?
            topic = Topic.where(id: topic_id).first

            if topic && post.topic.archetype != 'private_message' && topic.archetype != 'private_message'

              prefix = Discourse.base_url

              reflected_post = nil
              if post_number.present?
                reflected_post = Post.where(topic_id: topic_id, post_number: post_number.to_i).first
              end

              reflected_url = "#{prefix}#{post.topic.relative_url(post.post_number)}"

              reflected_urls << reflected_url
              TopicLink.create(user_id: post.user_id,
                                     topic_id: topic_id,
                                     post_id: reflected_post.try(:id),
                                     url: reflected_url,
                                     domain: Discourse.current_hostname,
                                     reflection: true,
                                     internal: true,
                                     link_topic_id: post.topic_id,
                                     link_post_id: post.id)
            end
          end

        rescue URI::InvalidURIError
          # if the URI is invalid, don't store it.
        rescue ActionController::RoutingError
          # If we can't find the route, no big deal
        end
      end

      # Remove links that aren't there anymore
      if added_urls.present?
        TopicLink.delete_all ["(url not in (:urls)) AND (post_id = :post_id)", urls: added_urls, post_id: post.id]
        TopicLink.delete_all ["(url not in (:urls)) AND (link_post_id = :post_id)", urls: reflected_urls, post_id: post.id]
      else
        TopicLink.delete_all ["post_id = :post_id OR link_post_id = :post_id", post_id: post.id]
      end
    end
  end
end

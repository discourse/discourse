# frozen_string_literal: true

module Tangyzen
  class BlogSerializer < ApplicationSerializer
    attributes :id,
              :topic_id,
              :user_id,
              :category_id,
              :title,
              :featured_image_url,
              :author_name,
              :author_avatar_url,
              :reading_time,
              :excerpt,
              :tags,
              :published_at,
              :is_featured,
              :is_active,
              :is_published,
              :likes_count,
              :views_count,
              :shares_count,
              :hotness_score,
              :created_at,
              :updated_at
    
    has_one :topic, serializer: BasicTopicSerializer, embed: :objects
    has_one :user, serializer: BasicUserSerializer, embed: :objects
    
    # Computed attributes
    attribute :user_liked
    attribute :user_saved
    attribute :formatted_reading_time
    attribute :short_reading_time
    attribute :display_title
    attribute :featured_image
    attribute :author_display_name
    attribute :author_avatar
    attribute :tags_list
    attribute :is_published
    attribute :is_draft
    attribute :status_badge
    attribute :status_color
    attribute :recently_published
    
    def user_liked
      return false unless scope && scope[:current_user]
      object.liked_by?(scope[:current_user])
    end
    
    def user_saved
      return false unless scope && scope[:current_user]
      object.saved_by?(scope[:current_user])
    end
    
    def formatted_reading_time
      object.formatted_reading_time
    end
    
    def short_reading_time
      object.short_reading_time
    end
    
    def display_title
      object.display_title
    end
    
    def featured_image
      object.featured_image
    end
    
    def author_display_name
      object.author_display_name
    end
    
    def author_avatar
      object.author_avatar
    end
    
    def tags_list
      object.tags_list
    end
    
    def is_published
      object.is_published?
    end
    
    def is_draft
      object.is_draft?
    end
    
    def status_badge
      object.status_badge
    end
    
    def status_color
      object.status_color
    end
    
    def recently_published
      object.recently_published?
    end
    
    def include_topic?
      options[:include_topic]
    end
    
    def include_user?
      options[:include_user]
    end
  end
end

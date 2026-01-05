# frozen_string_literal: true

module Tangyzen
  class ArtSerializer < ApplicationSerializer
    attributes :id,
              :topic_id,
              :user_id,
              :category_id,
              :title,
              :medium,
              :dimensions,
              :tools,
              :image_url,
              :thumbnail_url,
              :description,
              :inspiration,
              :is_featured,
              :is_active,
              :likes_count,
              :views_count,
              :hotness_score,
              :created_at,
              :updated_at
    
    has_one :topic, serializer: BasicTopicSerializer, embed: :objects
    has_one :user, serializer: BasicUserSerializer, embed: :objects
    
    # Computed attributes
    attribute :user_liked
    attribute :user_saved
    attribute :excerpt
    attribute :medium_type
    attribute :medium_badge_color
    attribute :display_title
    attribute :formatted_dimensions
    attribute :tools_list
    attribute :is_digital
    attribute :is_traditional
    attribute :is_photography
    attribute :hd_url
    attribute :thumbnail
    
    def user_liked
      return false unless scope && scope[:current_user]
      object.liked_by?(scope[:current_user])
    end
    
    def user_saved
      return false unless scope && scope[:current_user]
      object.saved_by?(scope[:current_user])
    end
    
    def excerpt
      object.topic&.excerpt || object.description&.truncate(200) || ''
    end
    
    def medium_type
      object.medium_type
    end
    
    def medium_badge_color
      object.medium_badge_color
    end
    
    def display_title
      object.display_title
    end
    
    def formatted_dimensions
      object.formatted_dimensions
    end
    
    def tools_list
      object.tools_list
    end
    
    def is_digital
      object.is_digital?
    end
    
    def is_traditional
      object.is_traditional?
    end
    
    def is_photography
      object.is_photography?
    end
    
    def hd_url
      object.hd_url
    end
    
    def thumbnail
      object.thumbnail
    end
    
    def include_topic?
      options[:include_topic]
    end
    
    def include_user?
      options[:include_user]
    end
  end
end

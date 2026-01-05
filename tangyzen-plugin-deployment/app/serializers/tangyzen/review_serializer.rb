# frozen_string_literal: true

module Tangyzen
  class ReviewSerializer < ApplicationSerializer
    attributes :id,
              :topic_id,
              :user_id,
              :category_id,
              :product_name,
              :brand,
              :category_name,
              :rating,
              :pros,
              :cons,
              :product_url,
              :product_image_url,
              :price,
              :purchase_date,
              :verified_purchase,
              :is_featured,
              :is_active,
              :likes_count,
              :helpful_count,
              :hotness_score,
              :created_at,
              :updated_at
    
    has_one :topic, serializer: BasicTopicSerializer, embed: :objects
    has_one :user, serializer: BasicUserSerializer, embed: :objects
    
    # Computed attributes
    attribute :user_liked
    attribute :user_saved
    attribute :excerpt
    attribute :rating_stars
    attribute :rating_percent
    attribute :rating_badge_color
    attribute :pros_list
    attribute :cons_list
    attribute :overall_sentiment
    attribute :is_highly_rated
    attribute :is_low_rated
    attribute :verified_badge
    attribute :helpful_percentage
    
    def user_liked
      return false unless scope && scope[:current_user]
      object.liked_by?(scope[:current_user])
    end
    
    def user_saved
      return false unless scope && scope[:current_user]
      object.saved_by?(scope[:current_user])
    end
    
    def excerpt
      object.topic&.excerpt || ''
    end
    
    def rating_stars
      object.rating_stars
    end
    
    def rating_percent
      object.rating_percent
    end
    
    def rating_badge_color
      object.rating_badge_color
    end
    
    def pros_list
      object.pros_list
    end
    
    def cons_list
      object.cons_list
    end
    
    def overall_sentiment
      object.overall_sentiment
    end
    
    def is_highly_rated
      object.is_highly_rated?
    end
    
    def is_low_rated
      object.is_low_rated?
    end
    
    def verified_badge
      object.verified_badge
    end
    
    def helpful_percentage
      object.helpful_percentage
    end
    
    def include_topic?
      options[:include_topic]
    end
    
    def include_user?
      options[:include_user]
    end
  end
end

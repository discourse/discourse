# frozen_string_literal: true

module Tangyzen
  class MovieSerializer < ApplicationSerializer
    attributes :id,
              :topic_id,
              :user_id,
              :category_id,
              :title,
              :type,
              :director,
              :actors,
              :genres,
              :rating,
              :year,
              :poster_url,
              :trailer_url,
              :netflix_url,
              :amazon_url,
              :hulu_url,
              :duration,
              :age_rating,
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
    attribute :primary_genre
    attribute :genre_badges
    attribute :streaming_platforms
    attribute :actors_list
    attribute :type_display
    attribute :is_series
    
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
    
    def primary_genre
      object.primary_genre
    end
    
    def genre_badges
      object.genre_badges
    end
    
    def streaming_platforms
      object.streaming_platforms
    end
    
    def actors_list
      object.actors_list
    end
    
    def type_display
      object.type_display
    end
    
    def is_series
      object.is_series?
    end
    
    def include_topic?
      options[:include_topic]
    end
    
    def include_user?
      options[:include_user]
    end
  end
end

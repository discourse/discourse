# frozen_string_literal: true

module Tangyzen
  class MusicSerializer < ApplicationSerializer
    attributes :id,
              :topic_id,
              :user_id,
              :category_id,
              :artist_name,
              :album_name,
              :genre,
              :spotify_url,
              :apple_music_url,
              :youtube_url,
              :soundcloud_url,
              :cover_image_url,
              :release_date,
              :is_featured,
              :is_active,
              :likes_count,
              :plays_count,
              :hotness_score,
              :created_at,
              :updated_at
    
    has_one :topic, serializer: BasicTopicSerializer, embed: :objects
    has_one :user, serializer: BasicUserSerializer, embed: :objects
    
    # Computed attributes
    attribute :user_liked
    attribute :user_saved
    attribute :title
    attribute :excerpt
    attribute :streaming_links
    
    def user_liked
      return false unless scope && scope[:current_user]
      object.liked_by?(scope[:current_user])
    end
    
    def user_saved
      return false unless scope && scope[:current_user]
      object.saved_by?(scope[:current_user])
    end
    
    def title
      object.topic&.title
    end
    
    def excerpt
      object.topic&.excerpt || ''
    end
    
    def streaming_links
      object.streaming_links
    end
    
    def include_topic?
      options[:include_topic]
    end
    
    def include_user?
      options[:include_user]
    end
  end
end

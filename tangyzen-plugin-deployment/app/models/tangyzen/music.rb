# frozen_string_literal: true

module Tangyzen
  class Music < ActiveRecord::Base
    self.table_name = 'tangyzen_music'
    
    belongs_to :topic, foreign_key: :topic_id
    belongs_to :user, class_name: 'User', foreign_key: :user_id
    belongs_to :category, class_name: 'Category', foreign_key: :category_id
    
    has_many :likes, ->(music) {
      where(content_type: 'music', content_id: music.id)
    }, class_name: 'Tangyzen::Like'
    
    has_many :saves, ->(music) {
      where(content_type: 'music', content_id: music.id)
    }, class_name: 'Tangyzen::Save'
    
    validates :topic, presence: true
    validates :user, presence: true
    validates :artist_name, presence: true
    validates :genre, presence: true
    
    # Scopes
    scope :featured, -> { where(is_featured: true) }
    scope :active, -> { where(is_active: true) }
    scope :by_genre, ->(genre) { where(genre: genre) }
    scope :by_artist, ->(artist) { where('artist_name ILIKE ?', "%#{artist}%") }
    scope :trending, -> { order(hotness_score: :desc) }
    scope :latest, -> { order(created_at: :desc) }
    scope :most_liked, -> { order(likes_count: :desc) }
    
    # Methods
    def genre_badge_color
      genre_colors = {
        'rock' => '#ef4444',
        'pop' => '#f59e0b',
        'hip-hop' => '#8b5cf6',
        'electronic' => '#06b6d4',
        'classical' => '#10b981',
        'jazz' => '#f97316',
        'r&b' => '#ec4899',
        'country' => '#84cc16',
        'indie' => '#6366f1',
        'metal' => '#78716c'
      }
      genre_colors[genre.downcase] || '#8b5cf6'
    end
    
    def streaming_links
      links = {}
      links[:spotify] = spotify_url if spotify_url.present?
      links[:apple_music] = apple_music_url if apple_music_url.present?
      links[:youtube] = youtube_url if youtube_url.present?
      links[:soundcloud] = soundcloud_url if soundcloud_url.present?
      links
    end
    
    def liked_by?(user)
      return false unless user
      likes.exists?(user_id: user.id)
    end
    
    def saved_by?(user)
      return false unless user
      saves.exists?(user_id: user.id)
    end
    
    def recalculate_hotness!
      return unless topic
      
      likes_count = topic.like_count.to_f
      comments_count = (topic.posts_count - 1).to_f
      days_old = [(Time.now - topic.created_at) / 1.day, 1].max
      
      score = (likes_count + comments_count * 2) / (days_old ** 1.5)
      
      update(hotness_score: score)
    end
  end
end

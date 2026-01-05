# frozen_string_literal: true

module Tangyzen
  class Movie < ActiveRecord::Base
    self.table_name = 'tangyzen_movies'
    
    belongs_to :topic, foreign_key: :topic_id
    belongs_to :user, class_name: 'User', foreign_key: :user_id
    belongs_to :category, class_name: 'Category', foreign_key: :category_id
    
    has_many :likes, ->(movie) {
      where(content_type: 'movie', content_id: movie.id)
    }, class_name: 'Tangyzen::Like'
    
    has_many :saves, ->(movie) {
      where(content_type: 'movie', content_id: movie.id)
    }, class_name: 'Tangyzen::Save'
    
    validates :topic, presence: true
    validates :user, presence: true
    validates :title, presence: true
    
    # Scopes
    scope :featured, -> { where(is_featured: true) }
    scope :active, -> { where(is_active: true) }
    scope :by_genre, ->(genre) { where('genres @> ARRAY[?]', Array(genre)) }
    scope :by_year, ->(year) { where(year: year) }
    scope :by_type, ->(type) { where(type: type) }
    scope :trending, -> { order(hotness_score: :desc) }
    scope :latest, -> { order(created_at: :desc) }
    scope :highest_rated, -> { where('rating >= 4.0').order(rating: :desc) }
    scope :most_liked, -> { order(likes_count: :desc) }
    
    # Methods
    def primary_genre
      genres&.first
    end
    
    def genre_badges
      genres&.map { |g| { name: g, color: genre_color(g) } } || []
    end
    
    def genre_color(genre)
      genre_colors = {
        'action' => '#ef4444',
        'comedy' => '#f59e0b',
        'drama' => '#8b5cf6',
        'horror' => '#7f1d1d',
        'thriller' => '#3b82f6',
        'romance' => '#ec4899',
        'sci-fi' => '#06b6d4',
        'fantasy' => '#a855f7',
        'animation' => '#10b981',
        'documentary' => '#64748b',
        'crime' => '#1e293b',
        'adventure' => '#f97316'
      }
      genre_colors[genre.downcase] || '#6366f1'
    end
    
    def streaming_platforms
      platforms = {}
      platforms[:netflix] = netflix_url if netflix_url.present?
      platforms[:amazon] = amazon_url if amazon_url.present?
      platforms[:hulu] = hulu_url if hulu_url.present?
      platforms
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
    
    def actors_list
      actors&.join(', ')
    end
    
    def type_display
      type&.capitalize
    end
    
    def is_series?
      type == 'series'
    end
  end
end

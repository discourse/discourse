# frozen_string_literal: true

module Tangyzen
  class Review < ActiveRecord::Base
    self.table_name = 'tangyzen_reviews'
    
    belongs_to :topic, foreign_key: :topic_id
    belongs_to :user, class_name: 'User', foreign_key: :user_id
    belongs_to :category, class_name: 'Category', foreign_key: :category_id
    
    has_many :likes, ->(review) {
      where(content_type: 'review', content_id: review.id)
    }, class_name: 'Tangyzen::Like'
    
    has_many :saves, ->(review) {
      where(content_type: 'review', content_id: review.id)
    }, class_name: 'Tangyzen::Save'
    
    validates :topic, presence: true
    validates :user, presence: true
    validates :product_name, presence: true
    validates :rating, presence: true, inclusion: { in: 1..5 }
    
    # Scopes
    scope :featured, -> { where(is_featured: true) }
    scope :active, -> { where(is_active: true) }
    scope :by_category, ->(category) { where(category_name: category) }
    scope :by_rating, ->(rating) { where(rating: rating) }
    scope :high_rated, -> { where('rating >= 4.0') }
    scope :low_rated, -> { where('rating <= 2.0') }
    scope :verified, -> { where(verified_purchase: true) }
    scope :trending, -> { order(hotness_score: :desc) }
    scope :latest, -> { order(created_at: :desc) }
    scope :most_helpful, -> { order(helpful_count: :desc) }
    scope :most_liked, -> { order(likes_count: :desc) }
    
    # Methods
    def rating_stars
      '★' * rating + '☆' * (5 - rating)
    end
    
    def rating_percent
      (rating / 5.0 * 100).round
    end
    
    def rating_badge_color
      case rating
      when 5 then '#10b981'
      when 4 then '#22c55e'
      when 3 then '#f59e0b'
      when 2 then '#f97316'
      else '#ef4444'
      end
    end
    
    def pros_list
      pros&.join(' • ') || ''
    end
    
    def cons_list
      cons&.join(' • ') || ''
    end
    
    def overall_sentiment
      return 'positive' if rating >= 4
      return 'neutral' if rating == 3
      'negative'
    end
    
    def is_highly_rated?
      rating >= 4
    end
    
    def is_low_rated?
      rating <= 2
    end
    
    def verified_badge
      verified_purchase ? '✓ Verified Purchase' : nil
    end
    
    def helpful_percentage
      return 0 unless likes_count > 0
      ((helpful_count.to_f / likes_count) * 100).round
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
      
      score = ((likes_count * 2) + (comments_count * 3) + (helpful_count * 5)) / (days_old ** 1.5)
      
      update(hotness_score: score)
    end
  end
end

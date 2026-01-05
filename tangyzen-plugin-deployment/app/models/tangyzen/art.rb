# frozen_string_literal: true

module Tangyzen
  class Art < ActiveRecord::Base
    self.table_name = 'tangyzen_arts'
    
    belongs_to :topic, foreign_key: :topic_id
    belongs_to :user, class_name: 'User', foreign_key: :user_id
    belongs_to :category, class_name: 'Category', foreign_key: :category_id
    
    has_many :likes, ->(art) {
      where(content_type: 'art', content_id: art.id)
    }, class_name: 'Tangyzen::Like'
    
    has_many :saves, ->(art) {
      where(content_type: 'art', content_id: art.id)
    }, class_name: 'Tangyzen::Save'
    
    validates :topic, presence: true
    validates :user, presence: true
    validates :medium, presence: true
    
    # Scopes
    scope :featured, -> { where(is_featured: true) }
    scope :active, -> { where(is_active: true) }
    scope :by_medium, ->(medium) { where(medium: medium) }
    scope :trending, -> { order(hotness_score: :desc) }
    scope :latest, -> { order(created_at: :desc) }
    scope :most_liked, -> { order(likes_count: :desc) }
    scope :most_viewed, -> { order(views_count: :desc) }
    
    # Medium types
    DIGITAL_MEDIUMS = ['digital', '3d', 'vector', 'concept art']
    TRADITIONAL_MEDIUMS = ['oil', 'watercolor', 'acrylic', 'pencil', 'charcoal', 'ink']
    PHOTOGRAPHY_MEDIUMS = ['photography', 'digital photography', 'film photography']
    
    # Methods
    def medium_type
      return 'digital' if DIGITAL_MEDIUMS.include?(medium&.downcase)
      return 'traditional' if TRADITIONAL_MEDIUMS.include?(medium&.downcase)
      return 'photography' if PHOTOGRAPHY_MEDIUMS.include?(medium&.downcase)
      'other'
    end
    
    def medium_badge_color
      case medium_type
      when 'digital' then '#8b5cf6'
      when 'traditional' then '#f59e0b'
      when 'photography' then '#06b6d4'
      else '#64748b'
      end
    end
    
    def display_title
      title || 'Untitled'
    end
    
    def formatted_dimensions
      dimensions&.upcase || ''
    end
    
    def tools_list
      tools&.split(',').map(&:strip) || []
    end
    
    def is_digital?
      DIGITAL_MEDIUMS.include?(medium&.downcase)
    end
    
    def is_traditional?
      TRADITIONAL_MEDIUMS.include?(medium&.downcase)
    end
    
    def is_photography?
      PHOTOGRAPHY_MEDIUMS.include?(medium&.downcase)
    end
    
    def hd_url
      image_url
    end
    
    def thumbnail
      thumbnail_url || image_url
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
      views_weight = [views_count * 0.1, 100].min
      days_old = [(Time.now - topic.created_at) / 1.day, 1].max
      
      score = (likes_count + comments_count * 2 + views_weight) / (days_old ** 1.5)
      
      update(hotness_score: score)
    end
  end
end

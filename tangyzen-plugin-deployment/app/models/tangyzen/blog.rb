# frozen_string_literal: true

module Tangyzen
  class Blog < ActiveRecord::Base
    self.table_name = 'tangyzen_blogs'
    
    belongs_to :topic, foreign_key: :topic_id
    belongs_to :user, class_name: 'User', foreign_key: :user_id
    belongs_to :category, class_name: 'Category', foreign_key: :category_id
    
    has_many :likes, ->(blog) {
      where(content_type: 'blog', content_id: blog.id)
    }, class_name: 'Tangyzen::Like'
    
    has_many :saves, ->(blog) {
      where(content_type: 'blog', content_id: blog.id)
    }, class_name: 'Tangyzen::Save'
    
    validates :topic, presence: true
    validates :user, presence: true
    validates :title, presence: true
    validates :reading_time, presence: true, numericality: { greater_than: 0 }
    
    # Scopes
    scope :featured, -> { where(is_featured: true) }
    scope :active, -> { where(is_active: true) }
    scope :published, -> { where(is_published: true) }
    scope :drafts, -> { where(is_published: false) }
    scope :trending, -> { order(hotness_score: :desc) }
    scope :latest, -> { order(published_at: :desc) }
    scope :most_liked, -> { order(likes_count: :desc) }
    scope :most_shared, -> { order(shares_count: :desc) }
    scope :most_viewed, -> { order(views_count: :desc) }
    scope :by_tag, ->(tag) { where('tags @> ARRAY[?]', Array(tag)) }
    
    # Methods
    def formatted_reading_time
      "#{reading_time} min read"
    end
    
    def short_reading_time
      return "#{reading_time}m" if reading_time < 60
      hours = (reading_time / 60).floor
      mins = (reading_time % 60)
      mins > 0 ? "#{hours}h #{mins}m" : "#{hours}h"
    end
    
    def display_title
      title
    end
    
    def featured_image
      featured_image_url || topic&.first_post&.image_url || '/images/default-blog.png'
    end
    
    def author_display_name
      author_name || user&.name || 'Anonymous'
    end
    
    def author_avatar
      author_avatar_url || user&.avatar_template || '/images/default-avatar.png'
    end
    
    def tags_list
      tags&.join(', ') || ''
    end
    
    def is_published?
      is_published
    end
    
    def is_draft?
      !is_published
    end
    
    def status_badge
      is_published ? 'Published' : 'Draft'
    end
    
    def status_color
      is_published ? '#10b981' : '#f59e0b'
    end
    
    def recently_published?
      is_published && published_at > 3.days.ago
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
      views_weight = [views_count * 0.05, 100].min
      shares_weight = shares_count * 10
      days_old = [(Time.now - published_at) / 1.day, 1].max
      
      score = (likes_count + comments_count * 2 + views_weight + shares_weight) / (days_old ** 1.5)
      
      update(hotness_score: score)
    end
  end
end

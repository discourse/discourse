# frozen_string_literal: true

module Tangyzen
  class Save < ActiveRecord::Base
    self.table_name = 'tangyzen_saves'
    
    belongs_to :user, class_name: 'User', foreign_key: :user_id
    
    validates :user, presence: true
    validates :content_type, presence: true, inclusion: { in: %w[deal music movie review art blog] }
    validates :content_id, presence: true
    
    # Scopes
    scope :by_type, ->(type) { where(content_type: type) }
    scope :by_user, ->(user) { where(user: user) }
    scope :recent, -> { where('created_at > ?', 30.days.ago) }
    scope :chronological, -> { order(created_at: :desc) }
    
    # Methods
    def content
      case content_type
      when 'deal'
        Tangyzen::Deal.find_by(id: content_id)
      when 'music'
        Tangyzen::Music.find_by(id: content_id)
      when 'movie'
        Tangyzen::Movie.find_by(id: content_id)
      when 'review'
        Tangyzen::Review.find_by(id: content_id)
      when 'art'
        Tangyzen::Art.find_by(id: content_id)
      when 'blog'
        Tangyzen::Blog.find_by(id: content_id)
      end
    end
  end
end

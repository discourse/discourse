# frozen_string_literal: true

module Tangyzen
  class ContentType < ActiveRecord::Base
    self.table_name = 'tangyzen_content_types'
    
    has_many :deals, class_name: 'Tangyzen::Deal', foreign_key: :content_type_id
    has_many :music, class_name: 'Tangyzen::Music', foreign_key: :content_type_id
    has_many :movies, class_name: 'Tangyzen::Movie', foreign_key: :content_type_id
    has_many :reviews, class_name: 'Tangyzen::Review', foreign_key: :content_type_id
    has_many :arts, class_name: 'Tangyzen::Art', foreign_key: :content_type_id
    has_many :blogs, class_name: 'Tangyzen::Blog', foreign_key: :content_type_id
    
    validates :name, presence: true, uniqueness: true
    validates :icon, presence: true
    validates :color, presence: true
    
    # Scopes
    scope :active, -> { where(is_active: true) }
    scope :by_name, ->(name) { where(name: name) }
    
    # Methods
    def display_name
      name.capitalize
    end
    
    def icon_emoji
      icon
    end
    
    def hex_color
      color
    end
    
    def total_count
      [
        deals&.count || 0,
        music&.count || 0,
        movies&.count || 0,
        reviews&.count || 0,
        arts&.count || 0,
        blogs&.count || 0
      ].sum
    end
  end
end

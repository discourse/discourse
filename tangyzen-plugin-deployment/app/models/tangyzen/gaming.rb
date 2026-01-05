# frozen_string_literal: true

module Tangyzen
  class Gaming < ActiveRecord::Base
    self.table_name = "tangyzen_gaming"

    belongs_to :user, class_name: "User"
    has_many :likes, as: :likeable, class_name: "::Tangyzen::Like", dependent: :destroy
    has_many :saves, as: :saveable, class_name: "::Tangyzen::Save", dependent: :destroy

    # Validations
    validates :user_id, presence: true
    validates :title, presence: true, length: { maximum: 200 }
    validates :game_name, presence: true, length: { maximum: 200 }
    validates :genre, presence: true, length: { maximum: 100 }
    validates :platform, presence: true, length: { maximum: 100 }
    validates :description, presence: true, length: { maximum: 5000 }
    validates :rating, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 10 }, allow_nil: true
    validates :playtime_hours, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

    # Scopes
    scope :featured, -> { where(featured: true) }
    scope :published, -> { where(status: 'published') }
    scope :draft, -> { where(status: 'draft') }
    scope :recent, -> { order(created_at: :desc) }
    scope :popular, -> { order(like_count: :desc) }

    # Callbacks
    before_save :set_featured_at
    after_create :notify_subscribers

    # Class methods
    GENRES = %w[
      Action Adventure RPG Strategy Simulation Sports Racing
      Puzzle Horror Survival Fighting Platformer FPS MOBA
      MMORPG Sandbox Card Board Party Music VisualNovel
      Casual Educational Educational Trivia Simulation
    ].freeze

    PLATFORMS = %w[
      PC PlayStation Xbox Nintendo iOS Android Stadia
      Switch PlayStation4 PlayStation5 XboxOne XboxSeriesX
      Mobile VR AR Cloud Browser Other
    ].freeze

    AGE_RATINGS = %w[Everyone Teen Mature Adult RatingPending].freeze

    STATUS_TYPES = %w[published draft archived].freeze

    def self.available_genres
      GENRES
    end

    def self.available_platforms
      PLATFORMS
    end

    def self.available_age_ratings
      AGE_RATINGS
    end

    def self.available_statuses
      STATUS_TYPES
    end

    def featured?
      featured == true
    end

    def published?
      status == 'published'
    end

    def draft?
      status == 'draft'
    end

    def screenshots
      return [] if screenshot_urls.blank?
      screenshot_urls.split(',').map(&:strip)
    end

    def is_free_to_play?
      free_to_play == true
    end

    def has_multiplayer?
      multiplayer == true
    end

    def has_coop?
      coop == true
    end

    def has_dlc?
      dlc_available == true
    end

    def has_in_game_purchases?
      in_game_purchases == true
    end

    def cross_platform?
      cross_platform == true
    end

    private

    def set_featured_at
      self.featured_at = Time.current if featured_changed? && featured?
    end

    def notify_subscribers
      # Logic to notify users who follow gaming content
      # Can be implemented with discourse notifications
    end
  end
end

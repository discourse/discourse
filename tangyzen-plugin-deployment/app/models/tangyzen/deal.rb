# frozen_string_literal: true

# TangyZen Deal Model
# Represents deal content type

module Tangyzen
  class Deal < ActiveRecord::Base
    self.table_name = 'tangyzen_deals'

    belongs_to :post, class_name: 'Post'
    belongs_to :category, class_name: 'Category'
    belongs_to :user, class_name: 'User'

    has_many :tags, through: :taggings
    has_many :images, class_name: 'Tangyzen::DealImage'

    validates :title, presence: true, length: { maximum: 255 }
    validates :body, presence: true
    validates :original_price, presence: true, numericality: { greater_than: 0 }
    validates :current_price, presence: true, numericality: { greater_than: 0 }
    validates :deal_url, presence: true, url: true
    validates :store_name, presence: true

    scope :active, -> { where('expiry_date IS NULL OR expiry_date > ?', Time.current) }
    scope :featured, -> { where(is_featured: true) }
    scope :trending, -> { order('hotness_score DESC') }

    # Calculate hotness score for trending
    def self.calculate_hotness
      update_all(<<-SQL)
        hotness_score = (
          GREATEST(1, views_count) + 
          (likes_count * 2) + 
          (comments_count * 3)
        ) * EXP(
          -(EXTRACT(EPOCH FROM (NOW() - created_at)) / 86400.0)
        )
      SQL
    end

    # Filter by parameters
    def self.filter(params)
      results = all

      results = results.where(category_id: params[:category_id]) if params[:category_id].present?
      results = results.where('original_price >= ?', params[:min_price]) if params[:min_price].present?
      results = results.where('current_price <= ?', params[:max_price]) if params[:max_price].present?
      results = results.where('discount_percentage >= ?', params[:min_discount]) if params[:min_discount].present?
      results = results.where('LOWER(store_name) LIKE ?', "%#{params[:store].downcase}%") if params[:store].present?

      if params[:tag].present?
        results = results.joins(:tags).where('tags.name': params[:tag])
      end

      if params[:q].present?
        results = results.where('title ILIKE ? OR body ILIKE ?', 
          "%#{params[:q]}%", "%#{params[:q]}%")
      end

      results
    end

    # Order by parameter
    def self.order(params)
      case params[:sort]
      when 'popular'
        order('hotness_score DESC')
      when 'newest'
        order('created_at DESC')
      when 'price_asc'
        order('current_price ASC')
      when 'price_desc'
        order('current_price DESC')
      when 'discount'
        order('discount_percentage DESC')
      when 'expiry'
        order('expiry_date ASC')
      else
        order('created_at DESC')
      end
    end

    # Check if deal is expired
    def expired?
      expiry_date.present? && expiry_date < Time.current
    end

    # Get discount amount
    def discount_amount
      return 0 if original_price.nil? || current_price.nil?
      (original_price - current_price).round(2)
    end

    # Get formatted price
    def formatted_original_price
      format_price(original_price)
    end

    def formatted_current_price
      format_price(current_price)
    end

    private

    def format_price(price)
      return '$0.00' if price.nil?
      '$%.2f' % price
    end
  end
end

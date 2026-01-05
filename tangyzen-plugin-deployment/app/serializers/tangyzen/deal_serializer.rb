# frozen_string_literal: true

module Tangyzen
  class DealSerializer < ApplicationSerializer
    attributes :id,
               :title,
               :slug,
               :body,
               :excerpt,
               :original_price,
               :current_price,
               :discount_percentage,
               :discount_amount,
               :deal_url,
               :store_name,
               :coupon_code,
               :expiry_date,
               :is_featured,
               :is_active,
               :created_at,
               :updated_at,
               :views_count,
               :likes_count,
               :comments_count,
               :hotness_score

    has_one :category, serializer: BasicCategorySerializer
    has_one :user, serializer: BasicUserSerializer
    has_many :images, serializer: DealImageSerializer
    has_many :tags, serializer: TagSerializer

    def excerpt
      object.excerpt || object.body.truncate(200)
    end

    def discount_amount
      object.discount_amount
    end

    def is_active
      !object.expired?
    end

    def formatted_original_price
      object.formatted_original_price
    end

    def formatted_current_price
      object.formatted_current_price
    end
  end
end

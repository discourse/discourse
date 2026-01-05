# frozen_string_literal: true

module Tangyzen
  class ReviewsController < ApplicationController
    requires_login except: [:index, :show, :featured, :trending, :categories, :top_rated]
    
    before_action :find_review, only: [:show, :update, :destroy, :like, :unlike, :save, :unsave, :helpful]
    
    def index
      limit = params[:limit].to_i > 0 ? params[:limit].to_i : 20
      page = params[:page].to_i > 0 ? params[:page].to_i : 1
      
      scope = Tangyzen::Review.where(is_active: true)
      
      # Apply filters
      scope = scope.where(category_name: params[:category]) if params[:category].present?
      scope = scope.where(rating: params[:rating]) if params[:rating].present?
      scope = scope.where('product_name ILIKE ?', "%#{params[:search]}%") if params[:search].present?
      
      # Apply sorting
      case params[:sort]
      when 'latest'
        scope = scope.order(created_at: :desc)
      when 'highest_rated'
        scope = scope.order(rating: :desc)
      when 'most_helpful'
        scope = scope.order(helpful_count: :desc)
      when 'popular'
        scope = scope.order(likes_count: :desc)
      else
        scope = scope.order(hotness_score: :desc)
      end
      
      reviews = scope.offset((page - 1) * limit).limit(limit)
      total = scope.count
      
      render json: {
        reviews: ActiveModel::ArraySerializer.new(
          reviews,
          each_serializer: Tangyzen::ReviewSerializer
        ).as_json,
        meta: {
          page: page,
          limit: limit,
          total: total
        }
      }
    end
    
    def show
      @review.increment!(:views_count)
      render json: Tangyzen::ReviewSerializer.new(@review)
    end
    
    def create
      topic = Topic.create!(
        title: params[:product_name] || 'Product Review',
        user: current_user,
        category_id: params[:category_id],
        raw: params[:body] || ''
      )
      
      PostCreator.new(
        current_user,
        topic_id: topic.id,
        raw: params[:body] || '',
        skip_validations: false
      ).create
      
      review = Tangyzen::Review.create!(
        topic: topic,
        user: current_user,
        category_id: params[:category_id],
        product_name: params[:product_name],
        brand: params[:brand],
        category_name: params[:category_name],
        rating: params[:rating],
        pros: params[:pros] || [],
        cons: params[:cons] || [],
        product_url: params[:product_url],
        product_image_url: params[:product_image_url],
        price: params[:price],
        purchase_date: params[:purchase_date],
        verified_purchase: params[:verified_purchase] || false,
        hotness_score: calculate_hotness_score(topic)
      )
      
      topic.update_custom_fields(
        'tangyzen_content_type' => 'review',
        'tangyzen_review_data' => {
          product: review.product_name,
          rating: review.rating,
          verified: review.verified_purchase
        }.to_json
      )
      
      if params[:tag_names].present?
        params[:tag_names].each { |tag_name| topic.tags << Tag.find_or_create_by(name: tag_name) }
      end
      
      render json: {
        review: Tangyzen::ReviewSerializer.new(review),
        topic_id: topic.id
      }, status: :created
    end
    
    def update
      return render json: { error: 'Unauthorized' }, status: :unauthorized unless can_edit?(@review)
      
      @review.update!(
        product_name: params[:product_name] if params[:product_name].present?,
        rating: params[:rating] if params[:rating].present?,
        pros: params[:pros] if params[:pros].present?,
        cons: params[:cons] if params[:cons].present?,
        product_image_url: params[:product_image_url] if params[:product_image_url].present?,
        price: params[:price] if params[:price].present?
      )
      
      render json: Tangyzen::ReviewSerializer.new(@review)
    end
    
    def destroy
      return render json: { error: 'Unauthorized' }, status: :unauthorized unless can_edit?(@review)
      
      topic = @review.topic
      @review.destroy
      topic.destroy
      
      head :no_content
    end
    
    def featured
      reviews = Tangyzen::Review
        .where(is_featured: true, is_active: true)
        .order(hotness_score: :desc)
        .limit(6)
      
      render json: {
        reviews: ActiveModel::ArraySerializer.new(
          reviews,
          each_serializer: Tangyzen::ReviewSerializer
        ).as_json
      }
    end
    
    def trending
      reviews = Tangyzen::Review
        .where(is_active: true)
        .where('created_at > ?', 7.days.ago)
        .order(hotness_score: :desc)
        .limit(10)
      
      render json: {
        reviews: ActiveModel::ArraySerializer.new(
          reviews,
          each_serializer: Tangyzen::ReviewSerializer
        ).as_json
      }
    end
    
    def categories
      categories = Tangyzen::Review
        .where(is_active: true)
        .group(:category_name)
        .count
        .sort_by { |_, count| -count }
      
      render json: {
        categories: categories.map { |category, count| { name: category, count: count } }
      }
    end
    
    def top_rated
      reviews = Tangyzen::Review
        .where(is_active: true)
        .where('rating >= 4.0')
        .order(rating: :desc)
        .limit(10)
      
      render json: {
        reviews: ActiveModel::ArraySerializer.new(
          reviews,
          each_serializer: Tangyzen::ReviewSerializer
        ).as_json
      }
    end
    
    def like
      return render json: { error: 'Already liked' }, status: :conflict if already_liked?(@review)
      
      Tangyzen::Like.create!(user: current_user, content_type: 'review', content_id: @review.id)
      @review.increment!(:likes_count)
      
      render json: { review: Tangyzen::ReviewSerializer.new(@review), liked: true }
    end
    
    def unlike
      like = Tangyzen::Like.find_by(user: current_user, content_type: 'review', content_id: @review.id)
      return render json: { error: 'Not liked' }, status: :not_found unless like
      
      like.destroy
      @review.decrement!(:likes_count)
      
      render json: { review: Tangyzen::ReviewSerializer.new(@review), liked: false }
    end
    
    def save
      return render json: { error: 'Already saved' }, status: :conflict if already_saved?(@review)
      Tangyzen::Save.create!(user: current_user, content_type: 'review', content_id: @review.id)
      render json: { saved: true }
    end
    
    def unsave
      save = Tangyzen::Save.find_by(user: current_user, content_type: 'review', content_id: @review.id)
      return render json: { error: 'Not saved' }, status: :not_found unless save
      
      save.destroy
      render json: { saved: false }
    end
    
    def helpful
      return render json: { error: 'Cannot mark your own review as helpful' }, status: :forbidden if @review.user_id == current_user.id
      
      @review.increment!(:helpful_count)
      render json: { review: Tangyzen::ReviewSerializer.new(@review) }
    end
    
    private
    
    def find_review
      @review = Tangyzen::Review.find(params[:id])
    end
    
    def can_edit?(review)
      review.user_id == current_user.id || current_user.staff?
    end
    
    def already_liked?(review)
      Tangyzen::Like.exists?(user: current_user, content_type: 'review', content_id: review.id)
    end
    
    def already_saved?(review)
      Tangyzen::Save.exists?(user: current_user, content_type: 'review', content_id: review.id)
    end
    
    def calculate_hotness_score(topic)
      likes = topic.like_count.to_f
      comments = (topic.posts_count - 1).to_f
      days_old = [(Time.now - topic.created_at) / 1.day, 1].max
      (likes + comments * 2) / (days_old ** 1.5)
    end
  end
end

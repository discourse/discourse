# frozen_string_literal: true

module Tangyzen
  class ArtsController < ApplicationController
    requires_login except: [:index, :show, :featured, :trending, :mediums]
    
    before_action :find_art, only: [:show, :update, :destroy, :like, :unlike, :save, :unsave]
    
    def index
      limit = params[:limit].to_i > 0 ? params[:limit].to_i : 20
      page = params[:page].to_i > 0 ? params[:page].to_i : 1
      
      scope = Tangyzen::Art.where(is_active: true)
      
      # Apply filters
      scope = scope.where(medium: params[:medium]) if params[:medium].present?
      scope = scope.where('title ILIKE ? OR description ILIKE ?', "%#{params[:search]}%", "%#{params[:search]}%") if params[:search].present?
      
      # Apply sorting
      case params[:sort]
      when 'latest'
        scope = scope.order(created_at: :desc)
      when 'popular'
        scope = scope.order(likes_count: :desc)
      else
        scope = scope.order(hotness_score: :desc)
      end
      
      arts = scope.offset((page - 1) * limit).limit(limit)
      total = scope.count
      
      render json: {
        arts: ActiveModel::ArraySerializer.new(
          arts,
          each_serializer: Tangyzen::ArtSerializer
        ).as_json,
        meta: {
          page: page,
          limit: limit,
          total: total
        }
      }
    end
    
    def show
      @art.increment!(:views_count)
      render json: Tangyzen::ArtSerializer.new(@art)
    end
    
    def create
      topic = Topic.create!(
        title: params[:title] || 'Artwork',
        user: current_user,
        category_id: params[:category_id],
        raw: params[:description] || ''
      )
      
      PostCreator.new(
        current_user,
        topic_id: topic.id,
        raw: params[:description] || '',
        skip_validations: false
      ).create
      
      art = Tangyzen::Art.create!(
        topic: topic,
        user: current_user,
        category_id: params[:category_id],
        title: params[:title],
        medium: params[:medium],
        dimensions: params[:dimensions],
        tools: params[:tools],
        image_url: params[:image_url],
        thumbnail_url: params[:thumbnail_url],
        description: params[:description],
        inspiration: params[:inspiration],
        hotness_score: calculate_hotness_score(topic)
      )
      
      topic.update_custom_fields(
        'tangyzen_content_type' => 'art',
        'tangyzen_art_data' => {
          title: art.title,
          medium: art.medium
        }.to_json
      )
      
      if params[:tag_names].present?
        params[:tag_names].each { |tag_name| topic.tags << Tag.find_or_create_by(name: tag_name) }
      end
      
      render json: {
        art: Tangyzen::ArtSerializer.new(art),
        topic_id: topic.id
      }, status: :created
    end
    
    def update
      return render json: { error: 'Unauthorized' }, status: :unauthorized unless can_edit?(@art)
      
      @art.update!(
        title: params[:title] if params[:title].present?,
        medium: params[:medium] if params[:medium].present?,
        dimensions: params[:dimensions] if params[:dimensions].present?,
        tools: params[:tools] if params[:tools].present?,
        image_url: params[:image_url] if params[:image_url].present?,
        thumbnail_url: params[:thumbnail_url] if params[:thumbnail_url].present?,
        description: params[:description] if params[:description].present?,
        inspiration: params[:inspiration] if params[:inspiration].present?
      )
      
      render json: Tangyzen::ArtSerializer.new(@art)
    end
    
    def destroy
      return render json: { error: 'Unauthorized' }, status: :unauthorized unless can_edit?(@art)
      
      topic = @art.topic
      @art.destroy
      topic.destroy
      
      head :no_content
    end
    
    def featured
      arts = Tangyzen::Art
        .where(is_featured: true, is_active: true)
        .order(hotness_score: :desc)
        .limit(6)
      
      render json: {
        arts: ActiveModel::ArraySerializer.new(
          arts,
          each_serializer: Tangyzen::ArtSerializer
        ).as_json
      }
    end
    
    def trending
      arts = Tangyzen::Art
        .where(is_active: true)
        .where('created_at > ?', 7.days.ago)
        .order(hotness_score: :desc)
        .limit(10)
      
      render json: {
        arts: ActiveModel::ArraySerializer.new(
          arts,
          each_serializer: Tangyzen::ArtSerializer
        ).as_json
      }
    end
    
    def mediums
      mediums = Tangyzen::Art
        .where(is_active: true)
        .group(:medium)
        .count
        .sort_by { |_, count| -count }
      
      render json: {
        mediums: mediums.map { |medium, count| { name: medium, count: count } }
      }
    end
    
    def like
      return render json: { error: 'Already liked' }, status: :conflict if already_liked?(@art)
      
      Tangyzen::Like.create!(user: current_user, content_type: 'art', content_id: @art.id)
      @art.increment!(:likes_count)
      
      render json: { art: Tangyzen::ArtSerializer.new(@art), liked: true }
    end
    
    def unlike
      like = Tangyzen::Like.find_by(user: current_user, content_type: 'art', content_id: @art.id)
      return render json: { error: 'Not liked' }, status: :not_found unless like
      
      like.destroy
      @art.decrement!(:likes_count)
      
      render json: { art: Tangyzen::ArtSerializer.new(@art), liked: false }
    end
    
    def save
      return render json: { error: 'Already saved' }, status: :conflict if already_saved?(@art)
      Tangyzen::Save.create!(user: current_user, content_type: 'art', content_id: @art.id)
      render json: { saved: true }
    end
    
    def unsave
      save = Tangyzen::Save.find_by(user: current_user, content_type: 'art', content_id: @art.id)
      return render json: { error: 'Not saved' }, status: :not_found unless save
      
      save.destroy
      render json: { saved: false }
    end
    
    private
    
    def find_art
      @art = Tangyzen::Art.find(params[:id])
    end
    
    def can_edit?(art)
      art.user_id == current_user.id || current_user.staff?
    end
    
    def already_liked?(art)
      Tangyzen::Like.exists?(user: current_user, content_type: 'art', content_id: art.id)
    end
    
    def already_saved?(art)
      Tangyzen::Save.exists?(user: current_user, content_type: 'art', content_id: art.id)
    end
    
    def calculate_hotness_score(topic)
      likes = topic.like_count.to_f
      comments = (topic.posts_count - 1).to_f
      days_old = [(Time.now - topic.created_at) / 1.day, 1].max
      (likes + comments * 2) / (days_old ** 1.5)
    end
  end
end

# frozen_string_literal: true

module Tangyzen
  class MoviesController < ApplicationController
    requires_login except: [:index, :show, :featured, :trending, :genres]
    
    before_action :find_movie, only: [:show, :update, :destroy, :like, :unlike, :save, :unsave]
    
    def index
      limit = params[:limit].to_i > 0 ? params[:limit].to_i : 20
      page = params[:page].to_i > 0 ? params[:page].to_i : 1
      
      scope = Tangyzen::Movie.where(is_active: true)
      
      # Apply filters
      scope = scope.where(genres: { overlap: Array(params[:genre]) }) if params[:genre].present?
      scope = scope.where('title ILIKE ?', "%#{params[:search]}%") if params[:search].present?
      scope = scope.where(year: params[:year]) if params[:year].present?
      
      # Apply sorting
      case params[:sort]
      when 'latest'
        scope = scope.order(created_at: :desc)
      when 'highest_rated'
        scope = scope.order(rating: :desc)
      when 'popular'
        scope = scope.order(likes_count: :desc)
      else
        scope = scope.order(hotness_score: :desc)
      end
      
      movies = scope.offset((page - 1) * limit).limit(limit)
      total = scope.count
      
      render json: {
        movies: ActiveModel::ArraySerializer.new(
          movies,
          each_serializer: Tangyzen::MovieSerializer
        ).as_json,
        meta: {
          page: page,
          limit: limit,
          total: total
        }
      }
    end
    
    def show
      @movie.increment!(:views_count)
      render json: Tangyzen::MovieSerializer.new(@movie)
    end
    
    def create
      topic = Topic.create!(
        title: params[:title],
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
      
      movie = Tangyzen::Movie.create!(
        topic: topic,
        user: current_user,
        category_id: params[:category_id],
        title: params[:title],
        type: params[:type] || 'movie',
        director: params[:director],
        actors: params[:actors] || [],
        genres: params[:genres] || [],
        rating: params[:rating],
        year: params[:year],
        poster_url: params[:poster_url],
        trailer_url: params[:trailer_url],
        netflix_url: params[:netflix_url],
        amazon_url: params[:amazon_url],
        hulu_url: params[:hulu_url],
        duration: params[:duration],
        age_rating: params[:age_rating],
        hotness_score: calculate_hotness_score(topic)
      )
      
      topic.update_custom_fields(
        'tangyzen_content_type' => 'movie',
        'tangyzen_movie_data' => {
          title: movie.title,
          type: movie.type,
          rating: movie.rating
        }.to_json
      )
      
      if params[:tag_names].present?
        params[:tag_names].each { |tag_name| topic.tags << Tag.find_or_create_by(name: tag_name) }
      end
      
      render json: {
        movie: Tangyzen::MovieSerializer.new(movie),
        topic_id: topic.id
      }, status: :created
    end
    
    def update
      return render json: { error: 'Unauthorized' }, status: :unauthorized unless can_edit?(@movie)
      
      @movie.update!(
        title: params[:title] if params[:title].present?,
        director: params[:director] if params[:director].present?,
        rating: params[:rating] if params[:rating].present?,
        year: params[:year] if params[:year].present?,
        poster_url: params[:poster_url] if params[:poster_url].present?,
        trailer_url: params[:trailer_url] if params[:trailer_url].present?
      )
      
      render json: Tangyzen::MovieSerializer.new(@movie)
    end
    
    def destroy
      return render json: { error: 'Unauthorized' }, status: :unauthorized unless can_edit?(@movie)
      
      topic = @movie.topic
      @movie.destroy
      topic.destroy
      
      head :no_content
    end
    
    def featured
      movies = Tangyzen::Movie
        .where(is_featured: true, is_active: true)
        .order(hotness_score: :desc)
        .limit(6)
      
      render json: {
        movies: ActiveModel::ArraySerializer.new(
          movies,
          each_serializer: Tangyzen::MovieSerializer
        ).as_json
      }
    end
    
    def trending
      movies = Tangyzen::Movie
        .where(is_active: true)
        .where('created_at > ?', 7.days.ago)
        .order(hotness_score: :desc)
        .limit(10)
      
      render json: {
        movies: ActiveModel::ArraySerializer.new(
          movies,
          each_serializer: Tangyzen::MovieSerializer
        ).as_json
      }
    end
    
    def genres
      genres = Tangyzen::Movie
        .where(is_active: true)
        .pluck(:genres)
        .flatten
        .tally
        .sort_by { |_, count| -count }
      
      render json: {
        genres: genres.map { |genre, count| { name: genre, count: count } }
      }
    end
    
    def like
      return render json: { error: 'Already liked' }, status: :conflict if already_liked?(@movie)
      
      Tangyzen::Like.create!(user: current_user, content_type: 'movie', content_id: @movie.id)
      @movie.increment!(:likes_count)
      
      render json: { movie: Tangyzen::MovieSerializer.new(@movie), liked: true }
    end
    
    def unlike
      like = Tangyzen::Like.find_by(user: current_user, content_type: 'movie', content_id: @movie.id)
      return render json: { error: 'Not liked' }, status: :not_found unless like
      
      like.destroy
      @movie.decrement!(:likes_count)
      
      render json: { movie: Tangyzen::MovieSerializer.new(@movie), liked: false }
    end
    
    def save
      return render json: { error: 'Already saved' }, status: :conflict if already_saved?(@movie)
      Tangyzen::Save.create!(user: current_user, content_type: 'movie', content_id: @movie.id)
      render json: { saved: true }
    end
    
    def unsave
      save = Tangyzen::Save.find_by(user: current_user, content_type: 'movie', content_id: @movie.id)
      return render json: { error: 'Not saved' }, status: :not_found unless save
      
      save.destroy
      render json: { saved: false }
    end
    
    private
    
    def find_movie
      @movie = Tangyzen::Movie.find(params[:id])
    end
    
    def can_edit?(movie)
      movie.user_id == current_user.id || current_user.staff?
    end
    
    def already_liked?(movie)
      Tangyzen::Like.exists?(user: current_user, content_type: 'movie', content_id: movie.id)
    end
    
    def already_saved?(movie)
      Tangyzen::Save.exists?(user: current_user, content_type: 'movie', content_id: movie.id)
    end
    
    def calculate_hotness_score(topic)
      likes = topic.like_count.to_f
      comments = (topic.posts_count - 1).to_f
      days_old = [(Time.now - topic.created_at) / 1.day, 1].max
      (likes + comments * 2) / (days_old ** 1.5)
    end
  end
end

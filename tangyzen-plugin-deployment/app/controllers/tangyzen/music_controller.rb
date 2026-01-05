# frozen_string_literal: true

module Tangyzen
  class MusicController < ApplicationController
    requires_login except: [:index, :show, :featured, :trending, :genres, :artists]
    
    before_action :find_music, only: [:show, :update, :destroy, :like, :unlike, :save, :unsave]
    
    def index
      limit = params[:limit].to_i > 0 ? params[:limit].to_i : 20
      page = params[:page].to_i > 0 ? params[:page].to_i : 1
      
      scope = Tangyzen::Music.where(is_active: true)
      
      # Apply filters
      scope = scope.where(genre: params[:genre]) if params[:genre].present?
      scope = scope.where('artist_name ILIKE ?', "%#{params[:artist]}%") if params[:artist].present?
      
      # Apply sorting
      case params[:sort]
      when 'latest'
        scope = scope.order(created_at: :desc)
      when 'popular'
        scope = scope.order(likes_count: :desc)
      else
        scope = scope.order(hotness_score: :desc)
      end
      
      music = scope.offset((page - 1) * limit).limit(limit)
      total = scope.count
      
      render json: {
        music: ActiveModel::ArraySerializer.new(
          music,
          each_serializer: Tangyzen::MusicSerializer
        ).as_json,
        meta: {
          page: page,
          limit: limit,
          total: total
        }
      }
    end
    
    def show
      # Increment view count
      @music.increment!(:views_count)
      
      render json: Tangyzen::MusicSerializer.new(@music)
    end
    
    def create
      # Create topic first
      topic = Topic.create!(
        title: params[:title],
        user: current_user,
        category_id: params[:category_id],
        raw: params[:body] || ''
      )
      
      # Create post
      PostCreator.new(
        current_user,
        topic_id: topic.id,
        raw: params[:body] || '',
        skip_validations: false
      ).create
      
      # Create music record
      music = Tangyzen::Music.create!(
        topic: topic,
        user: current_user,
        category_id: params[:category_id],
        artist_name: params[:artist_name],
        album_name: params[:album_name],
        genre: params[:genre],
        spotify_url: params[:spotify_url],
        apple_music_url: params[:apple_music_url],
        youtube_url: params[:youtube_url],
        soundcloud_url: params[:soundcloud_url],
        cover_image_url: params[:cover_image_url],
        release_date: params[:release_date],
        hotness_score: calculate_hotness_score(topic)
      )
      
      # Update topic custom fields
      topic.update_custom_fields(
        'tangyzen_content_type' => 'music',
        'tangyzen_music_data' => {
          artist: music.artist_name,
          album: music.album_name,
          genre: music.genre
        }.to_json
      )
      
      # Add tags
      if params[:tag_names].present?
        params[:tag_names].each do |tag_name|
          tag = Tag.find_or_create_by(name: tag_name)
          topic.tags << tag
        end
      end
      
      render json: {
        music: Tangyzen::MusicSerializer.new(music),
        topic_id: topic.id
      }, status: :created
    end
    
    def update
      return render json: { error: 'Unauthorized' }, status: :unauthorized unless can_edit?(@music)
      
      @music.update!(
        artist_name: params[:artist_name] if params[:artist_name].present?,
        album_name: params[:album_name] if params[:album_name].present?,
        genre: params[:genre] if params[:genre].present?,
        spotify_url: params[:spotify_url] if params[:spotify_url].present?,
        apple_music_url: params[:apple_music_url] if params[:apple_music_url].present?,
        youtube_url: params[:youtube_url] if params[:youtube_url].present?,
        soundcloud_url: params[:soundcloud_url] if params[:soundcloud_url].present?,
        cover_image_url: params[:cover_image_url] if params[:cover_image_url].present?
      )
      
      render json: Tangyzen::MusicSerializer.new(@music)
    end
    
    def destroy
      return render json: { error: 'Unauthorized' }, status: :unauthorized unless can_edit?(@music)
      
      topic = @music.topic
      @music.destroy
      topic.destroy
      
      head :no_content
    end
    
    def featured
      music = Tangyzen::Music
        .where(is_featured: true, is_active: true)
        .order(hotness_score: :desc)
        .limit(6)
      
      render json: {
        music: ActiveModel::ArraySerializer.new(
          music,
          each_serializer: Tangyzen::MusicSerializer
        ).as_json
      }
    end
    
    def trending
      music = Tangyzen::Music
        .where(is_active: true)
        .where('created_at > ?', 7.days.ago)
        .order(hotness_score: :desc)
        .limit(10)
      
      render json: {
        music: ActiveModel::ArraySerializer.new(
          music,
          each_serializer: Tangyzen::MusicSerializer
        ).as_json
      }
    end
    
    def genres
      genres = Tangyzen::Music
        .where(is_active: true)
        .group(:genre)
        .count
        .sort_by { |_, count| -count }
      
      render json: {
        genres: genres.map { |genre, count| { name: genre, count: count } }
      }
    end
    
    def artists
      artists = Tangyzen::Music
        .where(is_active: true)
        .group(:artist_name)
        .count
        .sort_by { |_, count| -count }
        .take(20)
      
      render json: {
        artists: artists.map { |artist, count| { name: artist, count: count } }
      }
    end
    
    def like
      return render json: { error: 'Already liked' }, status: :conflict if already_liked?(@music)
      
      Tangyzen::Like.create!(
        user: current_user,
        content_type: 'music',
        content_id: @music.id
      )
      
      @music.increment!(:likes_count)
      
      render json: {
        music: Tangyzen::MusicSerializer.new(@music),
        liked: true
      }
    end
    
    def unlike
      like = Tangyzen::Like.find_by(
        user: current_user,
        content_type: 'music',
        content_id: @music.id
      )
      
      return render json: { error: 'Not liked' }, status: :not_found unless like
      
      like.destroy
      @music.decrement!(:likes_count)
      
      render json: {
        music: Tangyzen::MusicSerializer.new(@music),
        liked: false
      }
    end
    
    def save
      return render json: { error: 'Already saved' }, status: :conflict if already_saved?(@music)
      
      Tangyzen::Save.create!(
        user: current_user,
        content_type: 'music',
        content_id: @music.id
      )
      
      render json: { saved: true }
    end
    
    def unsave
      save = Tangyzen::Save.find_by(
        user: current_user,
        content_type: 'music',
        content_id: @music.id
      )
      
      return render json: { error: 'Not saved' }, status: :not_found unless save
      
      save.destroy
      
      render json: { saved: false }
    end
    
    private
    
    def find_music
      @music = Tangyzen::Music.find(params[:id])
    end
    
    def can_edit?(music)
      music.user_id == current_user.id || current_user.staff?
    end
    
    def already_liked?(music)
      Tangyzen::Like.exists?(
        user: current_user,
        content_type: 'music',
        content_id: music.id
      )
    end
    
    def already_saved?(music)
      Tangyzen::Save.exists?(
        user: current_user,
        content_type: 'music',
        content_id: music.id
      )
    end
    
    def calculate_hotness_score(topic)
      # Calculate hotness score based on views, likes, comments, and recency
      likes = topic.like_count.to_f
      comments = topic.posts_count.to_f - 1 # Exclude original post
      days_old = [(Time.now - topic.created_at) / 1.day, 1].max
      
      # Gravity algorithm (like Reddit's)
      (likes + comments * 2) / (days_old ** 1.5)
    end
  end
end

# frozen_string_literal: true

module Tangyzen
  class BlogsController < ApplicationController
    requires_login except: [:index, :show, :featured, :trending]
    
    before_action :find_blog, only: [:show, :update, :destroy, :like, :unlike, :save, :unsave, :share]
    
    def index
      limit = params[:limit].to_i > 0 ? params[:limit].to_i : 20
      page = params[:page].to_i > 0 ? params[:page].to_i : 1
      
      scope = Tangyzen::Blog.where(is_active: true, is_published: true)
      
      # Apply filters
      scope = scope.where('title ILIKE ? OR excerpt ILIKE ?', "%#{params[:search]}%", "%#{params[:search]}%") if params[:search].present?
      scope = scope.where('tags @> ARRAY[?]', Array(params[:tag])) if params[:tag].present?
      
      # Apply sorting
      case params[:sort]
      when 'latest'
        scope = scope.order(published_at: :desc)
      when 'popular'
        scope = scope.order(likes_count: :desc)
      when 'most_shared'
        scope = scope.order(shares_count: :desc)
      else
        scope = scope.order(hotness_score: :desc)
      end
      
      blogs = scope.offset((page - 1) * limit).limit(limit)
      total = scope.count
      
      render json: {
        blogs: ActiveModel::ArraySerializer.new(
          blogs,
          each_serializer: Tangyzen::BlogSerializer
        ).as_json,
        meta: {
          page: page,
          limit: limit,
          total: total
        }
      }
    end
    
    def show
      @blog.increment!(:views_count)
      render json: Tangyzen::BlogSerializer.new(@blog)
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
      
      blog = Tangyzen::Blog.create!(
        topic: topic,
        user: current_user,
        category_id: params[:category_id],
        title: params[:title],
        featured_image_url: params[:featured_image_url],
        author_name: params[:author_name] || current_user.name,
        author_avatar_url: params[:author_avatar_url] || current_user.avatar_template,
        reading_time: params[:reading_time] || calculate_reading_time(params[:body] || ''),
        excerpt: params[:excerpt] || generate_excerpt(params[:body] || ''),
        tags: params[:tags] || [],
        published_at: params[:published_at] || Time.now,
        hotness_score: calculate_hotness_score(topic)
      )
      
      topic.update_custom_fields(
        'tangyzen_content_type' => 'blog',
        'tangyzen_blog_data' => {
          title: blog.title,
          author: blog.author_name,
          reading_time: blog.reading_time
        }.to_json
      )
      
      if params[:tag_names].present?
        params[:tag_names].each { |tag_name| topic.tags << Tag.find_or_create_by(name: tag_name) }
      end
      
      render json: {
        blog: Tangyzen::BlogSerializer.new(blog),
        topic_id: topic.id
      }, status: :created
    end
    
    def update
      return render json: { error: 'Unauthorized' }, status: :unauthorized unless can_edit?(@blog)
      
      @blog.update!(
        title: params[:title] if params[:title].present?,
        featured_image_url: params[:featured_image_url] if params[:featured_image_url].present?,
        reading_time: params[:reading_time] if params[:reading_time].present?,
        excerpt: params[:excerpt] if params[:excerpt].present?,
        tags: params[:tags] if params[:tags].present?,
        is_published: params[:is_published] if params[:is_published].present?
      )
      
      render json: Tangyzen::BlogSerializer.new(@blog)
    end
    
    def destroy
      return render json: { error: 'Unauthorized' }, status: :unauthorized unless can_edit?(@blog)
      
      topic = @blog.topic
      @blog.destroy
      topic.destroy
      
      head :no_content
    end
    
    def featured
      blogs = Tangyzen::Blog
        .where(is_featured: true, is_active: true, is_published: true)
        .order(hotness_score: :desc)
        .limit(6)
      
      render json: {
        blogs: ActiveModel::ArraySerializer.new(
          blogs,
          each_serializer: Tangyzen::BlogSerializer
        ).as_json
      }
    end
    
    def trending
      blogs = Tangyzen::Blog
        .where(is_active: true, is_published: true)
        .where('published_at > ?', 7.days.ago)
        .order(hotness_score: :desc)
        .limit(10)
      
      render json: {
        blogs: ActiveModel::ArraySerializer.new(
          blogs,
          each_serializer: Tangyzen::BlogSerializer
        ).as_json
      }
    end
    
    def like
      return render json: { error: 'Already liked' }, status: :conflict if already_liked?(@blog)
      
      Tangyzen::Like.create!(user: current_user, content_type: 'blog', content_id: @blog.id)
      @blog.increment!(:likes_count)
      
      render json: { blog: Tangyzen::BlogSerializer.new(@blog), liked: true }
    end
    
    def unlike
      like = Tangyzen::Like.find_by(user: current_user, content_type: 'blog', content_id: @blog.id)
      return render json: { error: 'Not liked' }, status: :not_found unless like
      
      like.destroy
      @blog.decrement!(:likes_count)
      
      render json: { blog: Tangyzen::BlogSerializer.new(@blog), liked: false }
    end
    
    def save
      return render json: { error: 'Already saved' }, status: :conflict if already_saved?(@blog)
      Tangyzen::Save.create!(user: current_user, content_type: 'blog', content_id: @blog.id)
      render json: { saved: true }
    end
    
    def unsave
      save = Tangyzen::Save.find_by(user: current_user, content_type: 'blog', content_id: @blog.id)
      return render json: { error: 'Not saved' }, status: :not_found unless save
      
      save.destroy
      render json: { saved: false }
    end
    
    def share
      @blog.increment!(:shares_count)
      
      render json: {
        blog: Tangyzen::BlogSerializer.new(@blog),
        share_url: topic_url(@blog.topic)
      }
    end
    
    private
    
    def find_blog
      @blog = Tangyzen::Blog.find(params[:id])
    end
    
    def can_edit?(blog)
      blog.user_id == current_user.id || current_user.staff?
    end
    
    def already_liked?(blog)
      Tangyzen::Like.exists?(user: current_user, content_type: 'blog', content_id: blog.id)
    end
    
    def already_saved?(blog)
      Tangyzen::Save.exists?(user: current_user, content_type: 'blog', content_id: blog.id)
    end
    
    def calculate_hotness_score(topic)
      likes = topic.like_count.to_f
      comments = (topic.posts_count - 1).to_f
      days_old = [(Time.now - topic.created_at) / 1.day, 1].max
      (likes + comments * 2) / (days_old ** 1.5)
    end
    
    def calculate_reading_time(body)
      words = body.split.length
      (words / 200.0).ceil
    end
    
    def generate_excerpt(body)
      plain_text = body.gsub(/<[^>]+>/, '').strip
      words = plain_text.split
      words.first(30).join(' ') + (words.length > 30 ? '...' : '')
    end
  end
end

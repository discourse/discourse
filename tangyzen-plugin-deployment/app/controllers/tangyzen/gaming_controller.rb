# frozen_string_literal: true

module Tangyzen
  class GamingController < ::ApplicationController
    requires_plugin ::TangyzenPlugin.enabled

    before_action :ensure_logged_in, only: [:create, :update, :destroy]
    before_action :find_gaming, only: [:show, :update, :destroy]

    # GET /tangyzen/gaming.json
    def index
      gaming_posts = Gaming.order(created_at: :desc).limit(50)
      
      # 筛选支持
      gaming_posts = filter_by_status(gaming_posts) if params[:status].present?
      gaming_posts = filter_by_genre(gaming_posts) if params[:genre].present?
      gaming_posts = filter_by_platform(gaming_posts) if params[:platform].present?
      
      render_json_dump(
        gaming_posts: serialize_data(gaming_posts, GamingSerializer),
        total: gaming_posts.count
      )
    end

    # GET /tangyzen/gaming/featured.json
    def featured
      featured_posts = Gaming.where(featured: true)
                             .order(featured_at: :desc)
                             .limit(10)
      
      render_json_dump(
        featured_gaming: serialize_data(featured_posts, GamingSerializer),
        total: featured_posts.count
      )
    end

    # GET /tangyzen/gaming/trending.json
    def trending
      trending_posts = Gaming.order(view_count: :desc)
                             .limit(20)
      
      render_json_dump(
        trending_gaming: serialize_data(trending_posts, GamingSerializer),
        total: trending_posts.count
      )
    end

    # GET /tangyzen/gaming/:id.json
    def show
      # 增加浏览量
      @gaming.increment!(:view_count) if @gaming
      
      render_json_dump(
        gaming: serialize_data(@gaming, GamingSerializer)
      )
    end

    # POST /tangyzen/gaming.json
    def create
      gaming_params = params.require(:gaming).permit(
        :title,
        :description,
        :game_name,
        :genre,
        :platform,
        :developer,
        :publisher,
        :release_date,
        :age_rating,
        :multiplayer,
        :coop,
        :rating,
        :playtime_hours,
        :dlc_available,
        :in_game_purchases,
        :cross_platform,
        :free_to_play,
        :cover_image_url,
        :screenshot_urls,
        :video_url,
        :website_url,
        :status,
        :featured
      )

      gaming = Gaming.new(gaming_params.merge(user_id: current_user.id))

      if gaming.save
        render json: serialize_data(gaming, GamingSerializer), status: :created
      else
        render json: { errors: gaming.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # PUT /tangyzen/gaming/:id.json
    def update
      unless can_edit?(@gaming)
        return render json: { error: I18n.t("tangyzen.errors.not_authorized") }, status: :forbidden
      end

      gaming_params = params.require(:gaming).permit(
        :title,
        :description,
        :game_name,
        :genre,
        :platform,
        :developer,
        :publisher,
        :release_date,
        :age_rating,
        :multiplayer,
        :coop,
        :rating,
        :playtime_hours,
        :dlc_available,
        :in_game_purchases,
        :cross_platform,
        :free_to_play,
        :cover_image_url,
        :screenshot_urls,
        :video_url,
        :website_url,
        :status,
        :featured
      )

      if @gaming.update(gaming_params)
        render json: serialize_data(@gaming, GamingSerializer)
      else
        render json: { errors: @gaming.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # DELETE /tangyzen/gaming/:id.json
    def destroy
      unless can_delete?(@gaming)
        return render json: { error: I18n.t("tangyzen.errors.not_authorized") }, status: :forbidden
      end

      if @gaming.destroy
        head :no_content
      else
        render json: { error: I18n.t("tangyzen.errors.delete_failed") }, status: :unprocessable_entity
      end
    end

    # POST /tangyzen/gaming/:id/like.json
    def like
      return head :no_content unless @gaming
      
      like = Like.find_or_initialize_by(
        user_id: current_user.id,
        likeable: @gaming
      )
      
      if like.new_record?
        like.save
        @gaming.increment!(:like_count)
      end
      
      render json: { liked: true, like_count: @gaming.like_count }
    end

    # DELETE /tangyzen/gaming/:id/unlike.json
    def unlike
      return head :no_content unless @gaming
      
      like = Like.find_by(
        user_id: current_user.id,
        likeable: @gaming
      )
      
      if like&.destroy
        @gaming.decrement!(:like_count)
        render json: { liked: false, like_count: @gaming.like_count }
      else
        head :no_content
      end
    end

    # POST /tangyzen/gaming/:id/save.json
    def save
      return head :no_content unless @gaming
      
      saved_post = Save.find_or_initialize_by(
        user_id: current_user.id,
        saveable: @gaming
      )
      
      if saved_post.new_record?
        saved_post.save
        @gaming.increment!(:save_count)
      end
      
      render json: { saved: true, save_count: @gaming.save_count }
    end

    # DELETE /tangyzen/gaming/:id/unsave.json
    def unsave
      return head :no_content unless @gaming
      
      saved_post = Save.find_by(
        user_id: current_user.id,
        saveable: @gaming
      )
      
      if saved_post&.destroy
        @gaming.decrement!(:save_count)
        render json: { saved: false, save_count: @gaming.save_count }
      else
        head :no_content
      end
    end

    # PUT /tangyzen/gaming/:id/feature.json
    def feature
      unless is_staff?
        return render json: { error: I18n.t("tangyzen.errors.forbidden") }, status: :forbidden
      end
      
      if @gaming.update(featured: true, featured_at: Time.current)
        render json: serialize_data(@gaming, GamingSerializer)
      else
        render json: { errors: @gaming.errors.full_messages }, status: :unprocessable_entity
      end
    end

    private

    def find_gaming
      @gaming = Gaming.find_by(id: params[:id])
      render json: { error: I18n.t("tangyzen.errors.not_found") }, status: :not_found unless @gaming
    end

    def filter_by_status(scope)
      scope.where(status: params[:status])
    end

    def filter_by_genre(scope)
      scope.where("genre ILIKE ?", "%#{params[:genre]}%")
    end

    def filter_by_platform(scope)
      scope.where("platform ILIKE ?", "%#{params[:platform]}%")
    end

    def can_edit?(gaming)
      current_user.id == gaming.user_id || is_staff?
    end

    def can_delete?(gaming)
      current_user.id == gaming.user_id || is_staff?
    end
  end
end

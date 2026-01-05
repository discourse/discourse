# frozen_string_literal: true

module Tangyzen
  class AdminController < ::ApplicationController
    requires_plugin 'tangyzen-plugin'
    
    before_action :ensure_admin
    before_action :verify_api_key
    
    # GET /admin/plugins/tangyzen
    def overview
      render_json({
        stats: {
          total_deals: Tangyzen::Deal.count,
          total_gaming: Tangyzen::Gaming.count,
          total_music: Tangyzen::Music.count,
          total_movies: Tangyzen::Movie.count,
          total_reviews: Tangyzen::Review.count,
          total_art: Tangyzen::Art.count,
          total_blogs: Tangyzen::Blog.count,
          total_users: User.joins(:user_custom_fields)
            .where(user_custom_fields: { name: 'tangyzen_member', value: 'true' })
            .count,
          total_views: calculate_total_views,
          total_likes: calculate_total_likes
        },
        recent_activity: recent_activity,
        trending_content: trending_content
      })
    end
    
    # GET /admin/plugins/tangyzen/content/:type
    def content_list
      type = params[:type].downcase
      
      unless Tangyzen::CONTENT_TYPES.include?(type)
        return render_json_error("Invalid content type", 400)
      end
      
      klass = "Tangyzen::#{type.classify}".constantize
      
      scope = klass.all
      scope = scope.where(status: params[:status]) if params[:status].present?
      scope = scope.where(featured: true) if params[:featured] == 'true'
      
      page = params[:page] || 1
      per_page = params[:per_page] || 20
      
      paginated = scope.page(page).per(per_page)
      
      serializer_class = "Tangyzen::#{type.classify}Serializer".constantize
      
      render_json({
        items: ActiveModel::ArraySerializer.new(
          paginated,
          each_serializer: serializer_class
        ),
        meta: {
          current_page: page,
          total_pages: paginated.total_pages,
          total_count: paginated.total_count,
          per_page: per_page
        }
      })
    end
    
    # PATCH /admin/plugins/tangyzen/content/:type/:id
    def update_content
      type = params[:type].downcase
      id = params[:id]
      
      klass = "Tangyzen::#{type.classify}".constantize
      content = klass.find_by(id: id)
      
      unless content
        return render_json_error("Content not found", 404)
      end
      
      if content.update(permitted_content_params)
        render_json(success: true, message: "Content updated successfully")
      else
        render_json_error(content.errors.full_messages.join(', '), 422)
      end
    end
    
    # DELETE /admin/plugins/tangyzen/content/:type/:id
    def delete_content
      type = params[:type].downcase
      id = params[:id]
      
      klass = "Tangyzen::#{type.classify}".constantize
      content = klass.find_by(id: id)
      
      unless content
        return render_json_error("Content not found", 404)
      end
      
      if content.destroy
        render_json(success: true, message: "Content deleted successfully")
      else
        render_json_error("Failed to delete content", 422)
      end
    end
    
    # POST /admin/plugins/tangyzen/content/:type/:id/feature
    def feature_content
      type = params[:type].downcase
      id = params[:id]
      
      klass = "Tangyzen::#{type.classify}".constantize
      content = klass.find_by(id: id)
      
      unless content
        return render_json_error("Content not found", 404)
      end
      
      if content.update(featured: true, featured_at: Time.now)
        render_json(success: true, message: "Content featured successfully")
      else
        render_json_error("Failed to feature content", 422)
      end
    end
    
    # POST /admin/plugins/tangyzen/content/:type/:id/unfeature
    def unfeature_content
      type = params[:type].downcase
      id = params[:id]
      
      klass = "Tangyzen::#{type.classify}".constantize
      content = klass.find_by(id: id)
      
      unless content
        return render_json_error("Content not found", 404)
      end
      
      if content.update(featured: false, featured_at: nil)
        render_json(success: true, message: "Content unfeatured successfully")
      else
        render_json_error("Failed to unfeature content", 422)
      end
    end
    
    # GET /admin/plugins/tangyzen/users
    def users_list
      users = User.joins(:user_custom_fields)
        .where(user_custom_fields: { name: 'tangyzen_member', value: 'true' })
      
      page = params[:page] || 1
      per_page = params[:per_page] || 20
      
      paginated = users.page(page).per(per_page)
      
      render_json({
        users: paginated.map do |user|
          {
            id: user.id,
            username: user.username,
            email: user.email,
            created_at: user.created_at,
            trust_level: user.trust_level,
            post_count: user.post_count,
            topics_created: user.topics.count,
            total_contributions: calculate_contributions(user)
          }
        end,
        meta: {
          current_page: page,
          total_pages: paginated.total_pages,
          total_count: paginated.total_count,
          per_page: per_page
        }
      })
    end
    
    # GET /admin/plugins/tangyzen/analytics
    def analytics
      render_json({
        period: params[:period] || '7d',
        metrics: {
          views: calculate_views_by_period,
          likes: calculate_likes_by_period,
          submissions: calculate_submissions_by_period,
          active_users: calculate_active_users_by_period,
          content_by_type: content_distribution,
          engagement_rate: calculate_engagement_rate,
          top_categories: top_categories,
          trending_tags: trending_tags
        },
        charts: {
          daily_views: daily_views_data,
          daily_submissions: daily_submissions_data,
          content_growth: content_growth_data
        }
      })
    end
    
    # POST /admin/plugins/tangyzen/web3/sync
    def sync_web3_data
      return render_json_error("Web3 is not enabled", 403) unless SiteSetting.tangyzen_web3_enabled?
      
      Jobs.enqueue(:sync_web3, 
        collections: params[:collections],
        force_refresh: params[:force_refresh]
      )
      
      render_json(success: true, message: "Web3 sync job started")
    end
    
    # GET /admin/plugins/tangyzen/settings
    def settings
      render_json({
        api_key: SiteSetting.tangyzen_api_key,
        opensea_enabled: SiteSetting.tangyzen_opensea_enabled?,
        opensea_api_key: mask_api_key(SiteSetting.tangyzen_opensea_api_key),
        content_types: content_type_settings,
        moderation_settings: moderation_settings,
        web3_settings: web3_settings
      })
    end
    
    # PUT /admin/plugins/tangyzen/settings
    def update_settings
      params.permit!.each do |key, value|
        setting_key = "tangyzen_#{key}"
        if SiteSetting.respond_to?("#{setting_key}=")
          SiteSetting.send("#{setting_key}=", value)
        end
      end
      
      render_json(success: true, message: "Settings updated successfully")
    end
    
    # GET /admin/plugins/tangyzen/data-consistency
    def check_data_consistency
      issues = []
      
      Tangyzen::CONTENT_TYPES.each do |type|
        klass = "Tangyzen::#{type.classify}".constantize
        
        # Check orphaned records (no topic)
        orphaned = klass.where.missing(:topic).count
        if orphaned > 0
          issues << {
            type: type,
            issue: 'orphaned_without_topic',
            count: orphaned
          }
        end
        
        # Check orphaned records (no user)
        orphaned_users = klass.where.missing(:user).count
        if orphaned_users > 0
          issues << {
            type: type,
            issue: 'orphaned_without_user',
            count: orphaned_users
          }
        end
      end
      
      render_json({
        consistent: issues.empty?,
        issues: issues,
        total_checked: Tangyzen::CONTENT_TYPES.sum { |type| "Tangyzen::#{type.classify}".constantize.count }
      })
    end
    
    # POST /admin/plugins/tangyzen/repair-data
    def repair_data
      repairs_made = []
      
      Tangyzen::CONTENT_TYPES.each do |type|
        klass = "Tangyzen::#{type.classify}".constantize
        
        # Delete orphaned records
        deleted = klass.where.missing(:topic).delete_all
        if deleted > 0
          repairs_made << {
            type: type,
            action: 'deleted_orphaned_without_topic',
            count: deleted
          }
        end
        
        deleted_users = klass.where.missing(:user).delete_all
        if deleted_users > 0
          repairs_made << {
            type: type,
            action: 'deleted_orphaned_without_user',
            count: deleted_users
          }
        end
      end
      
      render_json({
        success: true,
        repairs_made: repairs_made
      })
    end
    
    private
    
    def ensure_admin
      raise Discourse::InvalidAccess.new unless current_user&.admin?
    end
    
    def verify_api_key
      api_key = request.headers['X-Tangyzen-API-Key'] || params[:api_key]
      expected_key = SiteSetting.tangyzen_api_key
      
      if expected_key.present? && api_key != expected_key
        raise Discourse::InvalidAccess.new("Invalid API key")
      end
    end
    
    def permitted_content_params
      params.permit(
        :status,
        :featured,
        :featured_at,
        :like_count,
        :view_count,
        # Add type-specific fields as needed
      )
    end
    
    def calculate_total_views
      Tangyzen::CONTENT_TYPES.sum do |type|
        klass = "Tangyzen::#{type.classify}".constantize
        klass.sum(:view_count)
      end
    end
    
    def calculate_total_likes
      Tangyzen::CONTENT_TYPES.sum do |type|
        klass = "Tangyzen::#{type.classify}".constantize
        klass.sum(:like_count)
      end
    end
    
    def recent_activity
      # Return recent submissions, likes, comments
      []
    end
    
    def trending_content
      # Return trending content based on engagement
      []
    end
    
    def calculate_contributions(user)
      Tangyzen::CONTENT_TYPES.sum do |type|
        klass = "Tangyzen::#{type.classify}".constantize
        klass.where(user_id: user.id).count
      end
    end
    
    def calculate_views_by_period
      # Calculate views based on period (7d, 30d, 90d)
      0
    end
    
    def calculate_likes_by_period
      0
    end
    
    def calculate_submissions_by_period
      0
    end
    
    def calculate_active_users_by_period
      0
    end
    
    def content_distribution
      Tangyzen::CONTENT_TYPES.each_with_object({}) do |type, hash|
        klass = "Tangyzen::#{type.classify}".constantize
        hash[type] = klass.count
      end
    end
    
    def calculate_engagement_rate
      # (likes + comments + saves) / views
      total_interactions = calculate_total_likes
      total_views = calculate_total_views
      return 0 if total_views == 0
      (total_interactions.to_f / total_views).round(4)
    end
    
    def top_categories
      # Return top performing categories
      []
    end
    
    def trending_tags
      # Return trending tags
      []
    end
    
    def daily_views_data
      # Array of daily view counts
      []
    end
    
    def daily_submissions_data
      # Array of daily submission counts
      []
    end
    
    def content_growth_data
      # Array of cumulative content counts
      []
    end
    
    def content_type_settings
      Tangyzen::CONTENT_TYPES.each_with_object({}) do |type, hash|
        enabled_key = "tangyzen_#{type}_enabled"
        auto_approve_key = "tangyzen_#{type}_auto_approve"
        
        hash[type] = {
          enabled: SiteSetting.respond_to?(enabled_key) ? SiteSetting.send(enabled_key) : true,
          auto_approve: SiteSetting.respond_to?(auto_approve_key) ? SiteSetting.send(auto_approve_key) : false
        }
      end
    end
    
    def moderation_settings
      {
        require_moderation: SiteSetting.respond_to?(:tangyzen_require_moderation) ? SiteSetting.tangyzen_require_moderation : false,
        moderation_queue_enabled: SiteSetting.respond_to?(:tangyzen_moderation_queue_enabled) ? SiteSetting.tangyzen_moderation_queue_enabled : true,
        auto_flag_threshold: SiteSetting.respond_to?(:tangyzen_auto_flag_threshold) ? SiteSetting.tangyzen_auto_flag_threshold : 3
      }
    end
    
    def web3_settings
      {
        enabled: SiteSetting.respond_to?(:tangyzen_web3_enabled) ? SiteSetting.tangyzen_web3_enabled : true,
        auto_sync_nfts: SiteSetting.respond_to?(:tangyzen_web3_auto_sync) ? SiteSetting.tangyzen_web3_auto_sync : true,
        sync_interval: SiteSetting.respond_to?(:tangyzen_web3_sync_interval) ? SiteSetting.tangyzen_web3_sync_interval : 3600,
        featured_collections: SiteSetting.respond_to?(:tangyzen_web3_featured_collections) ? SiteSetting.tangyzen_web3_featured_collections : ''
      }
    end
    
    def mask_api_key(key)
      return '' if key.blank?
      "#{key[0..7]}...#{key[-8..-1]}"
    end
    
    def render_json(object, status = 200)
      render json: object, status: status
    end
    
    def render_json_error(message, status = 400)
      render json: { error: message, success: false }, status: status
    end
  end
end

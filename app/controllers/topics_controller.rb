require_dependency 'topic_view'
require_dependency 'promotion'

class TopicsController < ApplicationController

  # Avatar is an image request, not XHR
  before_filter :ensure_logged_in, only: [:timings, 
                                          :destroy_timings, 
                                          :update, 
                                          :star, 
                                          :destroy, 
                                          :status, 
                                          :invite, 
                                          :mute, 
                                          :unmute, 
                                          :set_notifications,
                                          :move_posts]

  skip_before_filter :check_xhr, only: [:avatar, :show]
  caches_action :avatar, :cache_path => Proc.new {|c| "#{c.params[:post_number]}-#{c.params[:topic_id]}" }

  def show

    # Consider the user for a promotion if they're new
    if current_user.present?
      Promotion.new(current_user).review if current_user.trust_level == TrustLevel.Levels[:new]
    end

    @topic_view = TopicView.new(params[:id] || params[:topic_id], 
                                current_user, 
                                username_filters: params[:username_filters],
                                best_of: params[:best_of],
                                page: params[:page])

    anonymous_etag(@topic_view.topic) do
      # force the correct slug
      if params[:slug] && @topic_view.topic.slug != params[:slug]
        fullpath = request.fullpath

        split = fullpath.split('/')
        split[2] = @topic_view.topic.slug

        redirect_to split.join('/'), status: 301 
        return
      end

      # Figure out what we're filter on
      if params[:post_number].present?
        # Get posts near a post
        @topic_view.filter_posts_near(params[:post_number].to_i)
      elsif params[:posts_before].present?
        @topic_view.filter_posts_before(params[:posts_before].to_i)
      elsif params[:posts_after].present?
        @topic_view.filter_posts_after(params[:posts_after].to_i)
      else
        # No filter? Consider it a paged view, default to page 0 which is the first segment
        @topic_view.filter_posts_paged(params[:page].to_i)
      end
      View.create_for(@topic_view.topic, request.remote_ip, current_user)   
      
      @topic_view.draft_key = @topic_view.topic.draft_key
      @topic_view.draft_sequence = DraftSequence.current(current_user, @topic_view.draft_key)

      if (!request.xhr? || params[:track_visit]) && current_user
        TopicUser.track_visit! @topic_view.topic, current_user
        @topic_view.draft = Draft.get(current_user, @topic_view.draft_key, @topic_view.draft_sequence)
      end

      topic_view_serializer = TopicViewSerializer.new(@topic_view, scope: guardian, root: false)

      respond_to do |format|
        format.html do
          @canonical = "#{request.protocol}#{request.host_with_port}" + @topic_view.topic.relative_url

          if params[:post_number]
            @post = @topic_view.posts.select{|p| p.post_number == params[:post_number].to_i}.first
            page = ((params[:post_number].to_i - 1) / SiteSetting.posts_per_page) + 1          
            @canonical << "?page=#{page}" if page > 1 
          else 
            @canonical << "?page=#{params[:page]}" if params[:page] && params[:page].to_i > 1
          end

          last_post = @topic_view.posts[-1]
          if last_post.present? and (@topic_view.topic.highest_post_number > last_post.post_number)
            @next_page = (@topic_view.posts[0].post_number / SiteSetting.posts_per_page) + 2
          end

          store_preloaded("topic_#{@topic_view.topic.id}", MultiJson.dump(topic_view_serializer))
        end

        format.json do
          render_json_dump(topic_view_serializer)
        end
        
      end
    end

  end

  def destroy_timings
    PostTiming.destroy_for(current_user.id, params[:topic_id].to_i)
    render nothing: true
  end

  def update
    topic = Topic.where(id: params[:topic_id]).first
    guardian.ensure_can_edit!(topic)      
    topic.title = params[:title] if params[:title].present?

    # TODO: we may need smarter rules about converting archetypes
    if current_user.admin? 
      topic.archetype = "regular" if params[:archetype] == 'regular'
    end

    Topic.transaction do
      topic.save
      topic.change_category(params[:category])
    end

    render nothing: true
  end

  def status
    requires_parameters(:status, :enabled)

    raise Discourse::InvalidParameters.new(:status) unless %w(visible closed pinned archived).include?(params[:status])
    @topic = Topic.where(id: params[:topic_id].to_i).first
    guardian.ensure_can_moderate!(@topic)
    @topic.update_status(params[:status], (params[:enabled] == 'true'), current_user)
    render nothing: true
  end

  def star
    @topic = Topic.where(id: params[:topic_id].to_i).first
    guardian.ensure_can_see!(@topic)

    @topic.toggle_star(current_user, params[:starred] == 'true')
    render nothing: true
  end

  def mute  
    toggle_mute(true)
  end

  def unmute
    toggle_mute(false)
  end


  def destroy
    topic = Topic.where(id: params[:id]).first
    guardian.ensure_can_delete!(topic)
    topic.destroy
    render nothing: true
  end
  
  def excerpt
    render nothing: true  
  end

  def invite
    requires_parameter(:user)
    topic = Topic.where(id: params[:topic_id]).first
    guardian.ensure_can_invite_to!(topic)

    if topic.invite(current_user, params[:user]) 
      render json: success_json
    else
      render json: failed_json, status: 422
    end
  end

  def set_notifications
    topic = Topic.find(params[:topic_id].to_i)
    TopicUser.change(current_user, topic.id, notification_level: params[:notification_level].to_i)
    render json: success_json
  end

  def move_posts
    requires_parameters(:title, :post_ids)
    topic = Topic.where(id: params[:topic_id]).first
    guardian.ensure_can_move_posts!(topic)

    # Move the posts
    new_topic = topic.move_posts(current_user, params[:title], params[:post_ids].map {|p| p.to_i})

    if new_topic.present?
      render json: {success: true, url: new_topic.relative_url}
    else
      render json: {success: false}
    end
  end

  def timings
    # TODO: all this should be optimised, tested better

    last_seen_key = "user-last-seen:#{current_user.id}"
    last_seen = $redis.get(last_seen_key) 
    if last_seen.present?
      diff = (Time.now.to_f - last_seen.to_f).round
      if diff > 0
        User.update_all ["time_read = time_read + ?", diff], ["id = ? and time_read = ?", current_user.id, current_user.time_read]       
      end
    end    
    $redis.set(last_seen_key, Time.now.to_f)    

    original_unread = current_user.unread_notifications_by_type

    topic_id = params["topic_id"].to_i
    highest_seen = params["highest_seen"].to_i
    added_time = 0


    if params[:timings].present?      
      params[:timings].each do |post_number_str, t|
        post_number = post_number_str.to_i
        
        if post_number >= 0 
          if (highest_seen || 0) >= post_number
            Notification.mark_post_read(current_user, topic_id, post_number)
          end

          PostTiming.record_timing(topic_id: topic_id,
                                   post_number: post_number, 
                                   user_id: current_user.id, 
                                   msecs: t.to_i)
        end
      end 
    end

    TopicUser.update_last_read(current_user, topic_id, highest_seen, params[:topic_time].to_i)

    current_user.reload
   
    if current_user.unread_notifications_by_type != original_unread
      current_user.publish_notifications_state
    end

    render nothing: true
  end

  private

    def toggle_mute(v)
      @topic = Topic.where(id: params[:topic_id].to_i).first
      guardian.ensure_can_see!(@topic)

      @topic.toggle_mute(current_user, v)
      render nothing: true
    end

end

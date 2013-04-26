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
                                          :move_posts,
                                          :clear_pin]

  before_filter :consider_user_for_promotion, only: :show

  skip_before_filter :check_xhr, only: [:avatar, :show, :feed]
  caches_action :avatar, cache_path: Proc.new {|c| "#{c.params[:post_number]}-#{c.params[:topic_id]}" }

  def show
    create_topic_view

    anonymous_etag(@topic_view.topic) do
      redirect_to_correct_topic && return if slugs_do_not_match
      View.create_for(@topic_view.topic, request.remote_ip, current_user)
      track_visit_to_topic
      perform_show_response
    end

    canonical_url @topic_view.canonical_path
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

    # this is used to return the title to the client as it may have been
    # changed by "TextCleaner"
    render_serialized(topic, BasicTopicSerializer)
  end

  def similar_to
    requires_parameters(:title, :raw)
    title, raw = params[:title], params[:raw]

    raise Discourse::InvalidParameters.new(:title) if title.length < SiteSetting.min_title_similar_length
    raise Discourse::InvalidParameters.new(:raw) if raw.length < SiteSetting.min_body_similar_length

    topics = Topic.similar_to(title, raw)
    render_serialized(topics, BasicTopicSerializer)
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

  def clear_pin
    topic = Topic.where(id: params[:topic_id].to_i).first
    guardian.ensure_can_see!(topic)
    topic.clear_pin_for(current_user)
    render nothing: true
  end

  def timings
    PostTiming.process_timings(
      current_user,
      params[:topic_id].to_i,
      params[:topic_time].to_i,
      (params[:timings] || []).map{|post_number, t| [post_number.to_i, t.to_i]}
    )
    render nothing: true
  end

  def feed
    @topic_view = TopicView.new(params[:topic_id])
    anonymous_etag(@topic_view.topic) do
      render 'topics/show', formats: [:rss]
    end
  end

  private

  def create_topic_view
    opts = params.slice(:username_filters, :best_of, :page, :post_number, :posts_before, :posts_after, :best)
    @topic_view = TopicView.new(params[:id] || params[:topic_id], current_user, opts)
  end

  def toggle_mute(v)
    @topic = Topic.where(id: params[:topic_id].to_i).first
    guardian.ensure_can_see!(@topic)

    @topic.toggle_mute(current_user, v)
    render nothing: true
  end

  def consider_user_for_promotion
    Promotion.new(current_user).review if current_user.present?
  end

  def slugs_do_not_match
    params[:slug] && @topic_view.topic.slug != params[:slug]
  end

  def redirect_to_correct_topic
    fullpath = request.fullpath

    split = fullpath.split('/')
    split[2] = @topic_view.topic.slug

    redirect_to split.join('/'), status: 301
  end

  def track_visit_to_topic
    return unless should_track_visit_to_topic?
    TopicUser.track_visit! @topic_view.topic, current_user
    @topic_view.draft = Draft.get(current_user, @topic_view.draft_key, @topic_view.draft_sequence)
  end

  def should_track_visit_to_topic?
    (!request.xhr? || params[:track_visit]) && current_user
  end

  def perform_show_response
    topic_view_serializer = TopicViewSerializer.new(@topic_view, scope: guardian, root: false)
    respond_to do |format|
      format.html do
        store_preloaded("topic_#{@topic_view.topic.id}", MultiJson.dump(topic_view_serializer))
      end

      format.json do
        render_json_dump(topic_view_serializer)
      end
    end
  end
end

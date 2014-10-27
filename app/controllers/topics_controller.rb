require_dependency 'topic_view'
require_dependency 'promotion'
require_dependency 'url_helper'
require_dependency 'topics_bulk_action'

class TopicsController < ApplicationController
  include UrlHelper

  before_filter :ensure_logged_in, only: [:timings,
                                          :destroy_timings,
                                          :update,
                                          :star,
                                          :destroy,
                                          :recover,
                                          :status,
                                          :invite,
                                          :mute,
                                          :unmute,
                                          :set_notifications,
                                          :move_posts,
                                          :merge_topic,
                                          :clear_pin,
                                          :re_pin,
                                          :autoclose,
                                          :bulk,
                                          :reset_new,
                                          :change_post_owners]

  before_filter :consider_user_for_promotion, only: :show

  skip_before_filter :check_xhr, only: [:show, :feed]

  def id_for_slug
    topic = Topic.find_by(slug: params[:slug].downcase)
    guardian.ensure_can_see!(topic)
    raise Discourse::NotFound unless topic
    render json: {slug: topic.slug, topic_id: topic.id, url: topic.url}
  end

  def show
    flash["referer"] ||= request.referer

    # We'd like to migrate the wordpress feed to another url. This keeps up backwards compatibility with
    # existing installs.
    return wordpress if params[:best].present?

    opts = params.slice(:username_filters, :filter, :page, :post_number, :show_deleted)
    username_filters = opts[:username_filters]

    opts[:username_filters] = username_filters.split(',') if username_filters.is_a?(String)

    begin
      @topic_view = TopicView.new(params[:id] || params[:topic_id], current_user, opts)
    rescue Discourse::NotFound
      topic = Topic.find_by(slug: params[:id].downcase) if params[:id]
      raise Discourse::NotFound unless topic
      redirect_to_correct_topic(topic, opts[:post_number]) && return
    end

    page = params[:page].to_i
    if (page < 0) || ((page - 1) * SiteSetting.posts_chunksize > @topic_view.topic.highest_post_number)
      raise Discourse::NotFound
    end

    discourse_expires_in 1.minute

    redirect_to_correct_topic(@topic_view.topic, opts[:post_number]) && return if slugs_do_not_match || (!request.format.json? && params[:slug].nil?)

    track_visit_to_topic

    if should_track_visit_to_topic?
      @topic_view.draft = Draft.get(current_user, @topic_view.draft_key, @topic_view.draft_sequence)
    end

    perform_show_response

    canonical_url absolute_without_cdn(@topic_view.canonical_path)
  rescue Discourse::InvalidAccess => ex

    if current_user
      # If the user can't see the topic, clean up notifications for it.
      Notification.remove_for(current_user.id, params[:topic_id])
    end

    raise ex
  end

  def wordpress
    params.require(:best)
    params.require(:topic_id)
    params.permit(:min_trust_level, :min_score, :min_replies, :bypass_trust_level_score, :only_moderator_liked)

    opts = { best: params[:best].to_i,
      min_trust_level: params[:min_trust_level] ? params[:min_trust_level].to_i : 1,
      min_score: params[:min_score].to_i,
      min_replies: params[:min_replies].to_i,
      bypass_trust_level_score: params[:bypass_trust_level_score].to_i, # safe cause 0 means ignore
      only_moderator_liked: params[:only_moderator_liked].to_s == "true"
    }

    @topic_view = TopicView.new(params[:topic_id], current_user, opts)
    discourse_expires_in 1.minute

    wordpress_serializer = TopicViewWordpressSerializer.new(@topic_view, scope: guardian, root: false)
    render_json_dump(wordpress_serializer)
  end

  def posts
    params.require(:topic_id)
    params.require(:post_ids)

    @topic_view = TopicView.new(params[:topic_id], current_user, post_ids: params[:post_ids])
    render_json_dump(TopicViewPostsSerializer.new(@topic_view, scope: guardian, root: false))
  end

  def destroy_timings
    PostTiming.destroy_for(current_user.id, [params[:topic_id].to_i])
    render nothing: true
  end

  def update
    topic = Topic.find_by(id: params[:topic_id])
    guardian.ensure_can_edit!(topic)

    changes = {}
    changes[:title]       = params[:title]       if params[:title]
    changes[:category_id] = params[:category_id] if params[:category_id]

    success = true

    if changes.length > 0
      first_post = topic.ordered_posts.first
      success = PostRevisor.new(first_post, topic).revise!(current_user, changes)
    end

    # this is used to return the title to the client as it may have been changed by "TextCleaner"
    success ? render_serialized(topic, BasicTopicSerializer) : render_json_error(topic)
  end

  def similar_to
    params.require(:title)
    params.require(:raw)
    title, raw = params[:title], params[:raw]
    [:title, :raw].each { |key| check_length_of(key, params[key]) }

    # Only suggest similar topics if the site has a minimum amount of topics present.
    topics = Topic.similar_to(title, raw, current_user).to_a if Topic.count_exceeds_minimum?

    render_serialized(topics, BasicTopicSerializer)
  end

  def status
    params.require(:status)
    params.require(:enabled)
    status, topic_id  = params[:status], params[:topic_id].to_i
    enabled = (params[:enabled] == 'true')

    check_for_status_presence(:status, status)
    @topic = Topic.find_by(id: topic_id)
    guardian.ensure_can_moderate!(@topic)
    @topic.update_status(status, enabled, current_user)
    render nothing: true
  end

  def star
    @topic = Topic.find_by(id: params[:topic_id].to_i)
    guardian.ensure_can_see!(@topic)

    @topic.toggle_star(current_user, params[:starred] == 'true')
    render nothing: true
  end

  def mute
    toggle_mute
  end

  def unmute
    toggle_mute
  end

  def autoclose
    params.permit(:auto_close_time)
    params.require(:auto_close_based_on_last_post)

    topic = Topic.find_by(id: params[:topic_id].to_i)
    guardian.ensure_can_moderate!(topic)

    topic.auto_close_based_on_last_post = params[:auto_close_based_on_last_post]
    topic.set_auto_close(params[:auto_close_time], current_user)

    if topic.save
      render json: success_json.merge!({
        auto_close_at: topic.auto_close_at,
        auto_close_hours: topic.auto_close_hours
      })
    else
      render_json_error(topic)
    end
  end

  def make_banner
    topic = Topic.find_by(id: params[:topic_id].to_i)
    guardian.ensure_can_moderate!(topic)

    topic.make_banner!(current_user)

    render nothing: true
  end

  def remove_banner
    topic = Topic.find_by(id: params[:topic_id].to_i)
    guardian.ensure_can_moderate!(topic)

    topic.remove_banner!(current_user)

    render nothing: true
  end

  def destroy
    topic = Topic.find_by(id: params[:id])
    guardian.ensure_can_delete!(topic)

    first_post = topic.ordered_posts.first
    PostDestroyer.new(current_user, first_post, { context: params[:context] }).destroy

    render nothing: true
  end

  def recover
    topic = Topic.where(id: params[:topic_id]).with_deleted.first
    guardian.ensure_can_recover_topic!(topic)

    first_post = topic.posts.with_deleted.order(:post_number).first
    PostDestroyer.new(current_user, first_post).recover

    render nothing: true
  end

  def excerpt
    render nothing: true
  end

  def remove_allowed_user
    params.require(:username)
    topic = Topic.find_by(id: params[:topic_id])
    guardian.ensure_can_remove_allowed_users!(topic)

    if topic.remove_allowed_user(params[:username])
      render json: success_json
    else
      render json: failed_json, status: 422
    end
  end

  def invite
    username_or_email = params[:user] ? fetch_username : fetch_email

    topic = Topic.find_by(id: params[:topic_id])

    group_ids = Group.lookup_group_ids(params)
    guardian.ensure_can_invite_to!(topic,group_ids)

    if topic.invite(current_user, username_or_email, group_ids)
      user = User.find_by_username_or_email(username_or_email)
      if user
        render_json_dump BasicUserSerializer.new(user, scope: guardian, root: 'user')
      else
        render json: success_json
      end
    else
      render json: failed_json, status: 422
    end
  end

  def set_notifications
    topic = Topic.find(params[:topic_id].to_i)
    TopicUser.change(current_user, topic.id, notification_level: params[:notification_level].to_i)
    render json: success_json
  end

  def merge_topic
    params.require(:destination_topic_id)

    topic = Topic.find_by(id: params[:topic_id])
    guardian.ensure_can_move_posts!(topic)

    dest_topic = topic.move_posts(current_user, topic.posts.pluck(:id), destination_topic_id: params[:destination_topic_id].to_i)
    render_topic_changes(dest_topic)
  end

  def move_posts
    params.require(:post_ids)
    params.require(:topic_id)
    params.permit(:category_id)

    topic = Topic.find_by(id: params[:topic_id])
    guardian.ensure_can_move_posts!(topic)

    dest_topic = move_posts_to_destination(topic)
    render_topic_changes(dest_topic)
  rescue ActiveRecord::RecordInvalid => ex
    render_json_error(ex)
  end

  def change_post_owners
    params.require(:post_ids)
    params.require(:topic_id)
    params.require(:username)

    guardian.ensure_can_change_post_owner!

    post_ids = params[:post_ids].to_a
    topic = Topic.find_by(id: params[:topic_id].to_i)
    new_user = User.find_by(username: params[:username])

    return render json: failed_json, status: 422 unless post_ids && topic && new_user

    ActiveRecord::Base.transaction do
      post_ids.each do |post_id|
        post = Post.find(post_id)
        # update topic owner (first avatar)
        topic.user = new_user if post.is_first_post?
        post.set_owner(new_user, current_user)
      end
    end

    topic.update_statistics

    render json: success_json
  end

  def clear_pin
    topic = Topic.find_by(id: params[:topic_id].to_i)
    guardian.ensure_can_see!(topic)
    topic.clear_pin_for(current_user)
    render nothing: true
  end

  def re_pin
    topic = Topic.find_by(id: params[:topic_id].to_i)
    guardian.ensure_can_see!(topic)
    topic.re_pin_for(current_user)
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
    discourse_expires_in 1.minute
    render 'topics/show', formats: [:rss]
  end

  def bulk
    if params[:topic_ids].present?
      topic_ids = params[:topic_ids].map {|t| t.to_i}
    elsif params[:filter] == 'unread'
      tq = TopicQuery.new(current_user)
      topic_ids = TopicQuery.unread_filter(tq.joined_topic_user).listable_topics.pluck(:id)
    else
      raise ActionController::ParameterMissing.new(:topic_ids)
    end

    operation = params.require(:operation).symbolize_keys
    raise ActionController::ParameterMissing.new(:operation_type) if operation[:type].blank?
    operator = TopicsBulkAction.new(current_user, topic_ids, operation)
    changed_topic_ids = operator.perform!
    render_json_dump topic_ids: changed_topic_ids
  end

  def reset_new
    current_user.user_stat.update_column(:new_since, Time.now)
    render nothing: true
  end

  private

  def toggle_mute
    @topic = Topic.find_by(id: params[:topic_id].to_i)
    guardian.ensure_can_see!(@topic)

    @topic.toggle_mute(current_user)
    render nothing: true
  end

  def consider_user_for_promotion
    Promotion.new(current_user).review if current_user.present?
  end

  def slugs_do_not_match
    params[:slug] && @topic_view.topic.slug != params[:slug]
  end

  def redirect_to_correct_topic(topic, post_number=nil)
    url = topic.relative_url
    url << "/#{post_number}" if post_number.to_i > 0
    url << ".json" if request.format.json?

    redirect_to url, status: 301
  end

  def track_visit_to_topic
    topic_id =  @topic_view.topic.id
    ip = request.remote_ip
    user_id = (current_user.id if current_user)
    track_visit = should_track_visit_to_topic?

    Scheduler::Defer.later "Track Link" do
      IncomingLink.add(
        referer: request.referer || flash[:referer],
        host: request.host,
        current_user: current_user,
        topic_id: @topic_view.topic.id,
        post_number: params[:post_number],
        username: request['u'],
        ip_address: request.remote_ip
      )
    end unless request.format.json?

    Scheduler::Defer.later "Track Visit" do
      TopicViewItem.add(topic_id, ip, user_id)
      if track_visit
        TopicUser.track_visit! topic_id, user_id
      end
    end

  end

  def should_track_visit_to_topic?
    !!((!request.format.json? || params[:track_visit]) && current_user)
  end

  def perform_show_response
    topic_view_serializer = TopicViewSerializer.new(@topic_view, scope: guardian, root: false)

    respond_to do |format|
      format.html do
        @description_meta = @topic_view.topic.excerpt
        store_preloaded("topic_#{@topic_view.topic.id}", MultiJson.dump(topic_view_serializer))
      end

      format.json do
        render_json_dump(topic_view_serializer)
      end
    end
  end

  def render_topic_changes(dest_topic)
    if dest_topic.present?
      render json: {success: true, url: dest_topic.relative_url}
    else
      render json: {success: false}
    end
  end

  def move_posts_to_destination(topic)
    args = {}
    args[:title] = params[:title] if params[:title].present?
    args[:destination_topic_id] = params[:destination_topic_id].to_i if params[:destination_topic_id].present?
    args[:category_id] = params[:category_id].to_i if params[:category_id].present?

    topic.move_posts(current_user, post_ids_including_replies, args)
  end

  def check_length_of(key, attr)
    str = (key == :raw) ? "body" : key.to_s
    invalid_param(key) if attr.length < SiteSetting.send("min_#{str}_similar_length")
  end

  def check_for_status_presence(key, attr)
    invalid_param(key) unless %w(pinned_globally visible closed pinned archived).include?(attr)
  end

  def invalid_param(key)
    raise Discourse::InvalidParameters.new(key.to_sym)
  end

  def fetch_username
    params.require(:user)
    params[:user]
  end

  def fetch_email
    params.require(:email)
    params[:email]
  end

end

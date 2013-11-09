require_dependency 'topic_view'
require_dependency 'promotion'

class TopicsController < ApplicationController

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
                                          :autoclose]

  before_filter :consider_user_for_promotion, only: :show

  skip_before_filter :check_xhr, only: [:show, :feed]

  def show
    # We'd like to migrate the wordpress feed to another url. This keeps up backwards compatibility with
    # existing installs.
    return wordpress if params[:best].present?

    opts = params.slice(:username_filters, :filter, :page, :post_number)
    username_filters = opts[:username_filters]

    opts[:username_filters] = [username_filters] if username_filters.is_a?(String)

    begin
      @topic_view = TopicView.new(params[:id] || params[:topic_id], current_user, opts)
    rescue Discourse::NotFound
      topic = Topic.where(slug: params[:id]).first if params[:id]
      raise Discourse::NotFound unless topic
      return redirect_to(topic.relative_url)
    end

    discourse_expires_in 1.minute

    redirect_to_correct_topic && return if slugs_do_not_match

    # render workaround pseudo-static HTML page for old crawlers which ignores <noscript>
    # (see http://meta.discourse.org/t/noscript-tag-and-some-search-engines/8078)
    return render 'topics/plain', layout: false if (SiteSetting.enable_escaped_fragments && params.key?('_escaped_fragment_'))

    track_visit_to_topic

    if should_track_visit_to_topic?
      @topic_view.draft = Draft.get(current_user, @topic_view.draft_key, @topic_view.draft_sequence)
    end

    perform_show_response

    canonical_url @topic_view.canonical_path
  end

  def wordpress
    params.require(:best)
    params.require(:topic_id)
    params.permit(:min_trust_level, :min_score, :min_replies, :bypass_trust_level_score, :only_moderator_liked)
    opts = { best: params[:best].to_i,
      min_trust_level: params[:min_trust_level] ? 1 : params[:min_trust_level].to_i,
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
    PostTiming.destroy_for(current_user.id, params[:topic_id].to_i)
    render nothing: true
  end

  def update
    topic = Topic.where(id: params[:topic_id]).first
    title, archetype = params[:title], params[:archetype]
    guardian.ensure_can_edit!(topic)

    topic.title = params[:title] if title.present?
    # TODO: we may need smarter rules about converting archetypes
    topic.archetype = "regular" if current_user.admin? && archetype == 'regular'

    success = false
    Topic.transaction do
      success = topic.save
      success = topic.change_category(params[:category]) if success
    end
    # this is used to return the title to the client as it may have been
    # changed by "TextCleaner"
    success ? render_serialized(topic, BasicTopicSerializer) : render_json_error(topic)
  end

  def similar_to
    params.require(:title)
    params.require(:raw)
    title, raw = params[:title], params[:raw]
    [:title, :raw].each { |key| check_length_of(key, params[key]) }

    # Only suggest similar topics if the site has a minimmum amount of topics present.
    topics = Topic.similar_to(title, raw, current_user).to_a if Topic.count_exceeds_minimum?

    render_serialized(topics, BasicTopicSerializer)
  end

  def status
    params.require(:status)
    params.require(:enabled)
    status, topic_id  = params[:status], params[:topic_id].to_i
    enabled = (params[:enabled] == 'true')

    check_for_status_presence(:status, status)
    @topic = Topic.where(id: topic_id).first
    guardian.ensure_can_moderate!(@topic)
    @topic.update_status(status, enabled, current_user)
    render nothing: true
  end

  def star
    @topic = Topic.where(id: params[:topic_id].to_i).first
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
    raise Discourse::InvalidParameters.new(:auto_close_days) unless params.has_key?(:auto_close_days)
    @topic = Topic.where(id: params[:topic_id].to_i).first
    guardian.ensure_can_moderate!(@topic)
    @topic.set_auto_close(params[:auto_close_days], current_user)
    @topic.save
    render nothing: true
  end

  def destroy
    topic = Topic.where(id: params[:id]).first
    guardian.ensure_can_delete!(topic)
    topic.trash!(current_user)
    render nothing: true
  end

  def recover
    topic = Topic.where(id: params[:topic_id]).with_deleted.first
    guardian.ensure_can_recover_topic!(topic)
    topic.recover!
    render nothing: true
  end

  def excerpt
    render nothing: true
  end

  def remove_allowed_user
    params.require(:username)
    topic = Topic.where(id: params[:topic_id]).first
    guardian.ensure_can_remove_allowed_users!(topic)

    if topic.remove_allowed_user(params[:username])
      render json: success_json
    else
      render json: failed_json, status: 422
    end
  end

  def invite
    username_or_email = params[:user] ? fetch_username : fetch_email

    topic = Topic.where(id: params[:topic_id]).first
    guardian.ensure_can_invite_to!(topic)

    if topic.invite(current_user, username_or_email)
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

    topic = Topic.where(id: params[:topic_id]).first
    guardian.ensure_can_move_posts!(topic)

    dest_topic = topic.move_posts(current_user, topic.posts.pluck(:id), destination_topic_id: params[:destination_topic_id].to_i)
    render_topic_changes(dest_topic)
  end

  def move_posts
    params.require(:post_ids)
    params.require(:topic_id)
    params.permit(:category_id)

    topic = Topic.where(id: params[:topic_id]).first
    guardian.ensure_can_move_posts!(topic)

    dest_topic = move_posts_to_destination(topic)
    render_topic_changes(dest_topic)
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
    discourse_expires_in 1.minute
    render 'topics/show', formats: [:rss]
  end

  private

  def toggle_mute
    @topic = Topic.where(id: params[:topic_id].to_i).first
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

  def redirect_to_correct_topic
    fullpath = request.fullpath

    split = fullpath.split('/')
    split[2] = @topic_view.topic.slug

    redirect_to split.join('/'), status: 301
  end

  def track_visit_to_topic
    Jobs.enqueue(:view_tracker,
                    topic_id: @topic_view.topic.id,
                    ip: request.remote_ip,
                    user_id: (current_user.id if current_user),
                    track_visit: should_track_visit_to_topic?
                )

  end

  def should_track_visit_to_topic?
    !!((!request.xhr? || params[:track_visit]) && current_user)
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
    invalid_param(key) unless %w(visible closed pinned archived).include?(attr)
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

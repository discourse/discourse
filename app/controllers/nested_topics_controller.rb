# frozen_string_literal: true

class NestedTopicsController < ApplicationController
  include EmbedModeHandler

  skip_before_action :check_xhr, only: %i[show context]

  before_action :ensure_nested_replies_enabled
  before_action :find_topic_with_topic_view, only: %i[show children context]
  before_action :find_topic, only: %i[pin toggle activity]
  before_action :ensure_not_pm
  before_action :set_embed_class, only: %i[show context]
  after_action :track_visit, only: %i[show context]
  after_action :allow_embed_mode, only: %i[show context]

  # GET /n/:slug/:topic_id (HTML + JSON)
  # HTML: preloads initial data into the Ember shell (crawlers redirect to flat view)
  # JSON page 0: includes topic metadata, OP post, sort, and message_bus_last_id
  # JSON page 1+: returns only roots for pagination
  def show
    if spa_boot_request?
      if use_crawler_layout?
        redirect_to "/t/#{params[:slug]}/#{params[:topic_id]}", status: :moved_permanently
        return
      end

      store_preloaded("nested_topic_#{@topic.id}", MultiJson.dump(list_roots_response(page: 0)))
      render_flat_topic_html
      return
    end

    page = params[:page].to_i.clamp(0, 1000)
    render json: list_roots_response(page: page)
  end

  # GET /n/:slug/:topic_id/children/:post_number
  def children
    NestedTopic::ListChildren.call(
      service_params.deep_merge(
        params: {
          parent_post_number: params[:post_number].to_i,
          sort: validated_sort,
          page: params[:page].to_i.clamp(0, 1000),
          depth: params[:depth].to_i.clamp(1, 100),
        },
        topic_view: @topic_view,
      ),
    ) do
      on_success { |response:| render json: response }
      on_failed_contract { raise Discourse::NotFound }
      on_failure { raise Discourse::NotFound }
    end
  end

  # GET /n/:slug/:topic_id/:post_number (HTML + JSON)
  # HTML: preloads context data into the Ember shell (crawlers redirect to flat view)
  # JSON param: context (integer) -- controls ancestor depth.
  #   nil/absent = windowed ancestor chain capped at max_depth (deep-links, notifications)
  #   0 = no ancestors, target at depth 0 ("Continue this thread")
  def context
    if spa_boot_request?
      if use_crawler_layout?
        redirect_to "/t/#{params[:slug]}/#{params[:topic_id]}/#{params[:post_number]}",
                    status: :moved_permanently
        return
      end

      store_preloaded("nested_topic_#{@topic.id}", MultiJson.dump(show_context_response))
      render_flat_topic_html(post_number: params[:post_number].to_i)
      return
    end

    render json: show_context_response
  end

  # PUT /n/:slug/:topic_id/pin
  def pin
    NestedTopic::TogglePin.call(service_params.deep_merge(params: { topic_id: @topic.id })) do
      on_success { |nested_topic:| render json: { pinned_post_ids: nested_topic.pinned_post_ids } }
      on_failed_contract { raise Discourse::NotFound }
      on_model_not_found(:topic) { raise Discourse::NotFound }
      on_model_not_found(:post) { raise Discourse::NotFound }
      on_failed_policy(:staff_can_edit) { raise Discourse::InvalidAccess }
      on_failed_policy(:post_is_root) { raise Discourse::InvalidParameters.new(:post_id) }
      on_failed_policy(:within_pin_limit) { raise Discourse::InvalidParameters.new(:post_id) }
      on_failure { raise Discourse::InvalidParameters }
    end
  end

  # GET /n/:slug/:topic_id/activity
  def activity
    post_types = [Post.types[:small_action]]
    post_types << Post.types[:whisper] if guardian.user&.whisperer?

    posts =
      @topic
        .posts
        .where(post_type: post_types)
        .where.not(action_code: [nil, ""])
        .includes(:user)
        .order(:created_at)

    Post.preload_custom_fields(posts, %w[action_code_who action_code_path])

    creator = @topic.user
    actions = [
      {
        action_code: "topic_created",
        created_at: @topic.created_at,
        username: creator&.username,
        avatar_template: creator&.avatar_template,
      },
    ]

    actions.concat(
      posts
        .select { |post| guardian.can_see_post?(post) }
        .map do |post|
          {
            id: post.id,
            action_code: post.action_code,
            action_code_who: post.custom_fields["action_code_who"],
            action_code_path: post.custom_fields["action_code_path"],
            created_at: post.created_at,
            username: post.user&.username,
            avatar_template: post.user&.avatar_template,
            cooked: post.cooked,
          }
        end,
    )

    render json: { small_actions: actions }
  end

  # PUT /n/:slug/:topic_id/toggle
  def toggle
    NestedTopic::Toggle.call(service_params.deep_merge(params: { topic_id: @topic.id })) do
      on_success { |params:| render json: { is_nested_view: params.enabled } }
      on_failed_contract { raise Discourse::InvalidParameters }
      on_model_not_found(:topic) { raise Discourse::NotFound }
      on_failed_policy(:staff_can_edit) { raise Discourse::InvalidAccess }
      on_failure { raise Discourse::InvalidParameters }
    end
  end

  private

  def list_roots_response(page:)
    result = nil
    NestedTopic::ListRoots.call(
      service_params.deep_merge(
        params: {
          sort: validated_sort,
          page: page,
        },
        topic_view: @topic_view,
      ),
    ) do
      on_success { |response:| result = response }
      on_failed_contract { raise Discourse::NotFound }
      on_failure { raise Discourse::NotFound }
    end
    result
  end

  def render_flat_topic_html(post_number: nil)
    opts = {}
    opts[:post_number] = post_number if post_number.to_i > 0

    @topic_view = TopicView.new(@topic.id, current_user, opts)
    @topic = @topic_view.topic

    if should_track_visit?
      @topic_view.draft = Draft.get(current_user, @topic_view.draft_key, @topic_view.draft_sequence)
    end

    @tags = SiteSetting.tagging_enabled ? @topic_view.topic.tags.visible(guardian) : []
    @breadcrumbs = helpers.categories_breadcrumb(@topic_view.topic) || []
    @description_meta = @topic_view.topic.excerpt.presence || @topic_view.summary

    topic_view_serializer = TopicViewSerializer.new(@topic_view, scope: guardian, root: false)
    store_preloaded("topic_#{@topic_view.topic.id}", MultiJson.dump(topic_view_serializer))

    render "topics/show"
  end

  def show_context_response
    result = nil
    NestedTopic::ShowContext.call(
      service_params.deep_merge(
        params: {
          target_post_number: params[:post_number].to_i,
          sort: validated_sort,
          context_depth: params[:context]&.to_i,
        },
        topic_view: @topic_view,
      ),
    ) do
      on_success { |response:| result = response }
      on_failed_contract { raise Discourse::NotFound }
      on_model_not_found(:target_post) { raise Discourse::NotFound }
      on_failure { raise Discourse::NotFound }
    end
    result
  end

  def ensure_nested_replies_enabled
    raise Discourse::NotFound unless SiteSetting.nested_replies_enabled
  end

  def ensure_not_pm
    return unless @topic.private_message?

    if request.get?
      url = "/t/#{@topic.slug}/#{@topic.id}"
      post_number = params[:post_number].to_i
      url << "/#{post_number}" if post_number > 0
      redirect_to url, status: :found
    else
      raise Discourse::NotFound
    end
  end

  def find_topic_with_topic_view
    topic_id = params[:topic_id].to_i
    @topic_view =
      TopicView.new(topic_id, current_user, skip_custom_fields: true, skip_post_loading: true)
    @topic = @topic_view.topic
    guardian.ensure_can_see!(@topic)

    if should_track_visit?
      @topic_view.draft = Draft.get(current_user, @topic_view.draft_key, @topic_view.draft_sequence)
    end
  rescue Discourse::InvalidAccess
    raise Discourse::NotFound
  end

  def find_topic
    @topic = Topic.find_by(id: params[:topic_id].to_i)
    raise Discourse::NotFound if @topic.blank? || !guardian.can_see?(@topic)
  end

  def track_visit
    return if response.redirect?

    topic_id = @topic.id
    user_id = current_user&.id
    ip = request.remote_ip

    if should_track_visit?
      TopicsController.defer_track_visit(topic_id, user_id)
      self.class.defer_mark_caught_up(topic_id, user_id) if @topic.nested_view?
    end

    TopicsController.defer_topic_view(topic_id, ip, user_id)
  end

  # Screen-tracking only advances last_read for posts the viewport renders,
  # so collapsed/hidden replies leave a nested topic stuck unread in the
  # sidebar. Treat the visit itself as catching up.
  def self.defer_mark_caught_up(topic_id, user_id)
    Scheduler::Defer.later "Nested Topic Catch Up" do
      user = User.find_by(id: user_id)
      topic = Topic.find_by(id: topic_id)
      next if user.blank? || topic.blank?
      next unless topic.nested_view?

      highest =
        if user.whisperer?
          [topic.highest_staff_post_number.to_i, topic.highest_post_number.to_i].max
        else
          topic.highest_post_number.to_i
        end
      next if highest < 1

      TopicUser.update_last_read(user, topic_id, highest, 0, 0)
      Notification.mark_posts_read(user, topic_id, (1..highest).to_a)
    end
  end

  def should_track_visit?
    !!((!request.format.json? || params[:track_visit]) && current_user)
  end

  def validated_sort
    sort = params[:sort].to_s.downcase
    NestedReplies::Sort.valid?(sort) ? sort : SiteSetting.nested_replies_default_sort
  end
end

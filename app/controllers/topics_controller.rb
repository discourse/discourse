# frozen_string_literal: true

require_dependency 'topic_view'
require_dependency 'promotion'
require_dependency 'url_helper'
require_dependency 'topics_bulk_action'
require_dependency 'discourse_event'
require_dependency 'rate_limiter'
require_dependency 'topic_publisher'
require_dependency 'post_action_destroyer'

class TopicsController < ApplicationController
  requires_login only: [
    :timings,
    :destroy_timings,
    :update,
    :update_shared_draft,
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
    :status_update,
    :timer,
    :bulk,
    :reset_new,
    :change_post_owners,
    :change_timestamps,
    :archive_message,
    :move_to_inbox,
    :convert_topic,
    :bookmark,
    :publish,
    :reset_bump_date
  ]

  before_action :consider_user_for_promotion, only: :show

  skip_before_action :check_xhr, only: [:show, :feed]

  def id_for_slug
    topic = Topic.find_by(slug: params[:slug].downcase)
    guardian.ensure_can_see!(topic)
    raise Discourse::NotFound unless topic
    render json: { slug: topic.slug, topic_id: topic.id, url: topic.url }
  end

  def show
    if request.referer
      flash["referer"] ||= request.referer[0..255]
    end

    # We'd like to migrate the wordpress feed to another url. This keeps up backwards compatibility with
    # existing installs.
    return wordpress if params[:best].present?

    # work around people somehow sending in arrays,
    # arrays are not supported
    params[:page] = params[:page].to_i rescue 1

    opts = params.slice(:username_filters, :filter, :page, :post_number, :show_deleted)
    username_filters = opts[:username_filters]

    opts[:print] = true if params[:print].present?
    opts[:username_filters] = username_filters.split(',') if username_filters.is_a?(String)

    # Special case: a slug with a number in front should look by slug first before looking
    # up that particular number
    if params[:id] && params[:id] =~ /^\d+[^\d\\]+$/
      topic = Topic.find_by(slug: params[:id].downcase)
      return redirect_to_correct_topic(topic, opts[:post_number]) if topic
    end

    if opts[:print]
      raise Discourse::InvalidAccess unless SiteSetting.max_prints_per_hour_per_user > 0
      begin
        RateLimiter.new(current_user, "print-topic-per-hour", SiteSetting.max_prints_per_hour_per_user, 1.hour).performed! unless @guardian.is_admin?
      rescue RateLimiter::LimitExceeded
        return render_json_error I18n.t("rate_limiter.slow_down")
      end
    end

    begin
      @topic_view = TopicView.new(params[:id] || params[:topic_id], current_user, opts)
    rescue Discourse::NotFound
      if params[:id]
        topic = Topic.find_by(slug: params[:id].downcase)
        return redirect_to_correct_topic(topic, opts[:post_number]) if topic
      end
      raise Discourse::NotFound
    end

    page = params[:page]
    if (page < 0) || ((page - 1) * @topic_view.chunk_size > @topic_view.topic.highest_post_number)
      raise Discourse::NotFound
    end

    discourse_expires_in 1.minute

    if slugs_do_not_match || (!request.format.json? && params[:slug].nil?)
      redirect_to_correct_topic(@topic_view.topic, opts[:post_number])
      return
    end

    track_visit_to_topic

    if should_track_visit_to_topic?
      @topic_view.draft = Draft.get(current_user, @topic_view.draft_key, @topic_view.draft_sequence)
    end

    unless @topic_view.topic.visible
      response.headers['X-Robots-Tag'] = 'noindex'
    end

    canonical_url UrlHelper.absolute_without_cdn(@topic_view.canonical_path)

    # provide hint to crawlers only for now
    # we would like to give them a bit more signal about age of data
    if use_crawler_layout?
      if last_modified = @topic_view.posts&.map { |p| p.updated_at }&.max&.httpdate
        response.headers['Last-Modified'] = last_modified
      end
    end

    perform_show_response

  rescue Discourse::InvalidAccess => ex
    if !guardian.can_see_topic?(ex.obj) && guardian.can_get_access_to_topic?(ex.obj)
      return perform_hidden_topic_show_response(ex.obj)
    end

    if current_user
      # If the user can't see the topic, clean up notifications for it.
      Notification.remove_for(current_user.id, params[:topic_id])
    end

    if ex.obj && Topic === ex.obj && guardian.can_see_topic_if_not_deleted?(ex.obj)
      raise Discourse::NotFound.new(
        "topic was deleted",
        status: 410,
        check_permalinks: true,
        original_path: ex.obj.relative_url
      )
    end

    raise ex
  end

  def publish
    params.permit(:id, :destination_category_id)

    topic = Topic.find(params[:id])
    category = Category.find(params[:destination_category_id])

    guardian.ensure_can_publish_topic!(topic, category)
    topic = TopicPublisher.new(topic, current_user, category.id).publish!

    render_serialized(topic.reload, BasicTopicSerializer)
  end

  def wordpress
    params.require(:best)
    params.require(:topic_id)
    params.permit(:min_trust_level, :min_score, :min_replies, :bypass_trust_level_score, :only_moderator_liked)

    opts = {
      best: params[:best].to_i,
      min_trust_level: params[:min_trust_level] ? params[:min_trust_level].to_i : 1,
      min_score: params[:min_score].to_i,
      min_replies: params[:min_replies].to_i,
      bypass_trust_level_score: params[:bypass_trust_level_score].to_i, # safe cause 0 means ignore
      only_moderator_liked: params[:only_moderator_liked].to_s == "true",
      exclude_hidden: true
    }

    @topic_view = TopicView.new(params[:topic_id], current_user, opts)
    discourse_expires_in 1.minute

    wordpress_serializer = TopicViewWordpressSerializer.new(@topic_view, scope: guardian, root: false)
    render_json_dump(wordpress_serializer)
  end

  def post_ids
    params.require(:topic_id)
    params.permit(:post_number, :username_filters, :filter)

    options = {
      filter_post_number: params[:post_number],
      filter: params[:filter],
      skip_limit: true,
      asc: true,
      skip_custom_fields: true
    }

    fetch_topic_view(options)
    render_json_dump(post_ids: @topic_view.posts.pluck(:id))
  end

  def posts
    params.require(:topic_id)
    params.permit(:post_ids, :post_number, :username_filters, :filter, :include_suggested)

    include_suggested = params[:include_suggested] == "true"

    options = {
      filter_post_number: params[:post_number],
      post_ids: params[:post_ids],
      asc: ActiveRecord::Type::Boolean.new.deserialize(params[:asc]),
      filter: params[:filter],
      include_suggested: include_suggested,
      include_related: include_suggested,
    }

    fetch_topic_view(options)

    render_json_dump(TopicViewPostsSerializer.new(@topic_view,
      scope: guardian,
      root: false,
      include_raw: !!params[:include_raw]
    ))
  end

  def excerpts
    params.require(:topic_id)
    params.require(:post_ids)

    post_ids = params[:post_ids].map(&:to_i)
    unless Array === post_ids
      render_json_error("Expecting post_ids to contain a list of posts ids")
      return
    end

    if post_ids.length > 100
      render_json_error("Requested a chunk that is too big")
      return
    end

    @topic = Topic.with_deleted.where(id: params[:topic_id]).first
    guardian.ensure_can_see!(@topic)

    @posts = Post.where(hidden: false, deleted_at: nil, topic_id: @topic.id)
      .where('posts.id in (?)', post_ids)
      .joins("LEFT JOIN users u on u.id = posts.user_id")
      .pluck(:id, :cooked, :username)
      .map do |post_id, cooked, username|
        {
          post_id: post_id,
          username: username,
          excerpt: PrettyText.excerpt(cooked, 800, keep_emoji_images: true)
        }
      end

    render json: @posts.to_json
  end

  def destroy_timings
    topic_id = params[:topic_id].to_i

    if params[:last].to_s == "1"
      PostTiming.destroy_last_for(current_user, topic_id)
    else
      PostTiming.destroy_for(current_user.id, [topic_id])
    end

    last_notification = Notification
      .where(
        user_id: current_user.id,
        topic_id: topic_id
      )
      .order(created_at: :desc)
      .limit(1)
      .first

    if last_notification
      last_notification.update!(read: false)
    end

    render body: nil
  end

  def update_shared_draft
    topic = Topic.find_by(id: params[:id])
    guardian.ensure_can_edit!(topic)

    category = Category.where(id: params[:category_id].to_i).first
    guardian.ensure_can_publish_topic!(topic, category)

    row_count = SharedDraft.where(topic_id: topic.id).update_all(category_id: category.id)
    if row_count == 0
      SharedDraft.create(topic_id: topic.id, category_id: category.id)
    end

    render json: success_json
  end

  def update
    topic = Topic.find_by(id: params[:topic_id])
    guardian.ensure_can_edit!(topic)

    if params[:category_id] && (params[:category_id].to_i != topic.category_id.to_i)
      category = Category.find_by(id: params[:category_id])

      if category || (params[:category_id].to_i == 0)
        guardian.ensure_can_move_topic_to_category!(category)
      else
        return render_json_error(I18n.t('category.errors.not_found'))
      end

      if category && topic_tags = (params[:tags] || topic.tags.pluck(:name)).reject { |c| c.empty? }
        if topic_tags.present?
          allowed_tags = DiscourseTagging.filter_allowed_tags(
            Tag.all,
            guardian,
            category: category
          ).pluck("tags.name")

          invalid_tags = topic_tags - allowed_tags

          # Do not raise an error on a topic's hidden tags when not modifying tags
          if params[:tags].blank?
            invalid_tags.each do |tag_name|
              if DiscourseTagging.hidden_tag_names.include?(tag_name)
                invalid_tags.delete(tag_name)
              end
            end
          end

          if !invalid_tags.empty?
            if (invalid_tags & DiscourseTagging.hidden_tag_names).present?
              return render_json_error(I18n.t('category.errors.disallowed_tags_generic'))
            else
              return render_json_error(I18n.t('category.errors.disallowed_topic_tags', tags: invalid_tags.join(", ")))
            end
          end
        end
      end
    end

    changes = {}

    PostRevisor.tracked_topic_fields.each_key do |f|
      changes[f] = params[f] if params.has_key?(f)
    end

    changes.delete(:title) if topic.title == changes[:title]
    changes.delete(:category_id) if topic.category_id.to_i == changes[:category_id].to_i

    success = true

    if changes.length > 0
      first_post = topic.ordered_posts.first
      success = PostRevisor.new(first_post, topic).revise!(current_user, changes, validate_post: false)
    end

    # this is used to return the title to the client as it may have been changed by "TextCleaner"
    success ? render_serialized(topic, BasicTopicSerializer) : render_json_error(topic)
  end

  def feature_stats
    params.require(:category_id)
    category_id = params[:category_id].to_i

    visible_topics = Topic.listable_topics.visible

    render json: {
      pinned_in_category_count: visible_topics.where(category_id: category_id).where(pinned_globally: false).where.not(pinned_at: nil).count,
      pinned_globally_count: visible_topics.where(pinned_globally: true).where.not(pinned_at: nil).count,
      banner_count: Topic.listable_topics.where(archetype: Archetype.banner).count,
    }
  end

  def status
    params.require(:status)
    params.require(:enabled)
    params.permit(:until)

    status = params[:status]
    topic_id = params[:topic_id].to_i
    enabled = params[:enabled] == 'true'

    check_for_status_presence(:status, status)
    @topic = Topic.find_by(id: topic_id)
    guardian.ensure_can_moderate!(@topic)
    @topic.update_status(status, enabled, current_user, until: params[:until])

    render json: success_json.merge!(
      topic_status_update: TopicTimerSerializer.new(
        TopicTimer.find_by(topic: @topic), root: false
      )
    )
  end

  def mute
    toggle_mute
  end

  def unmute
    toggle_mute
  end

  def timer
    params.permit(:time, :based_on_last_post, :category_id)
    params.require(:status_type)

    status_type =
      begin
        TopicTimer.types.fetch(params[:status_type].to_sym)
      rescue
        invalid_param(:status_type)
      end

    topic = Topic.find_by(id: params[:topic_id])
    guardian.ensure_can_moderate!(topic)

    options = {
      by_user: current_user,
      based_on_last_post: params[:based_on_last_post]
    }

    options.merge!(category_id: params[:category_id]) if !params[:category_id].blank?

    topic_status_update = topic.set_or_create_timer(
      status_type,
      params[:time],
      options
    )

    if topic.save
      render json: success_json.merge!(
        execute_at: topic_status_update&.execute_at,
        duration: topic_status_update&.duration,
        based_on_last_post: topic_status_update&.based_on_last_post,
        closed: topic.closed,
        category_id: topic_status_update&.category_id
      )
    else
      render_json_error(topic)
    end
  end

  def make_banner
    topic = Topic.find_by(id: params[:topic_id].to_i)
    guardian.ensure_can_banner_topic!(topic)

    topic.make_banner!(current_user)

    render body: nil
  end

  def remove_banner
    topic = Topic.find_by(id: params[:topic_id].to_i)
    guardian.ensure_can_banner_topic!(topic)

    topic.remove_banner!(current_user)

    render body: nil
  end

  def remove_bookmarks
    topic = Topic.find(params[:topic_id].to_i)

    PostAction.joins(:post)
      .where(user_id: current_user.id)
      .where('topic_id = ?', topic.id).each do |pa|

      PostActionDestroyer.destroy(current_user, pa.post, :bookmark)
    end

    render body: nil
  end

  def archive_message
    toggle_archive_message(true)
  end

  def move_to_inbox
    toggle_archive_message(false)
  end

  def toggle_archive_message(archive)
    topic = Topic.find(params[:id].to_i)

    group_id = nil

    group_ids = current_user.groups.pluck(:id)
    if group_ids.present?
      allowed_groups = topic.allowed_groups
        .where('topic_allowed_groups.group_id IN (?)', group_ids).pluck(:id)
      allowed_groups.each do |id|
        if archive
          GroupArchivedMessage.archive!(id, topic)
          group_id = id
        else
          GroupArchivedMessage.move_to_inbox!(id, topic)
        end
      end
    end

    if topic.allowed_users.include?(current_user)
      if archive
        UserArchivedMessage.archive!(current_user.id, topic)
      else
        UserArchivedMessage.move_to_inbox!(current_user.id, topic)
      end
    end

    if group_id
      name = Group.find_by(id: group_id).try(:name)
      render_json_dump(group_name: name)
    else
      render body: nil
    end
  end

  def bookmark
    topic = Topic.find(params[:topic_id].to_i)
    first_post = topic.ordered_posts.first

    result = PostActionCreator.create(current_user, first_post, :bookmark)
    return render_json_error(result) if result.failed?

    render body: nil
  end

  def destroy
    topic = Topic.find_by(id: params[:id])
    guardian.ensure_can_delete!(topic)

    first_post = topic.ordered_posts.first
    PostDestroyer.new(current_user, first_post, context: params[:context]).destroy

    render body: nil
  end

  def recover
    topic = Topic.where(id: params[:topic_id]).with_deleted.first
    guardian.ensure_can_recover_topic!(topic)

    first_post = topic.posts.with_deleted.order(:post_number).first
    PostDestroyer.new(current_user, first_post, context: params[:context]).recover

    render body: nil
  end

  def excerpt
    render body: nil
  end

  def remove_allowed_user
    params.require(:username)
    topic = Topic.find_by(id: params[:topic_id])
    raise Discourse::NotFound unless topic
    user = User.find_by(username: params[:username])
    raise Discourse::NotFound unless user

    guardian.ensure_can_remove_allowed_users!(topic, user)

    if topic.remove_allowed_user(current_user, user)
      render json: success_json
    else
      render json: failed_json, status: 422
    end
  end

  def remove_allowed_group
    params.require(:name)
    topic = Topic.find_by(id: params[:topic_id])
    guardian.ensure_can_remove_allowed_users!(topic)

    if topic.remove_allowed_group(current_user, params[:name])
      render json: success_json
    else
      render json: failed_json, status: 422
    end
  end

  def invite_group
    group = Group.find_by(name: params[:group])
    raise Discourse::NotFound unless group

    topic = Topic.find_by(id: params[:topic_id])

    unless pm_has_slots?(topic)
      return render_json_error(I18n.t("pm_reached_recipients_limit",
        recipients_limit: SiteSetting.max_allowed_message_recipients
      ))
    end

    if topic.private_message?
      guardian.ensure_can_invite_group_to_private_message!(group, topic)
      topic.invite_group(current_user, group)
      render_json_dump BasicGroupSerializer.new(group, scope: guardian, root: 'group')
    else
      render json: failed_json, status: 422
    end
  end

  def invite
    topic = Topic.find_by(id: params[:topic_id])
    raise Discourse::InvalidParameters.new unless topic

    username_or_email = params[:user] ? fetch_username : fetch_email

    groups = Group.lookup_groups(
      group_ids: params[:group_ids],
      group_names: params[:group_names]
    )

    unless pm_has_slots?(topic)
      return render_json_error(I18n.t("pm_reached_recipients_limit",
        recipients_limit: SiteSetting.max_allowed_message_recipients
      ))
    end

    guardian.ensure_can_invite_to!(topic)
    group_ids = groups.map(&:id)

    begin
      if topic.invite(current_user, username_or_email, group_ids, params[:custom_message])
        user = User.find_by_username_or_email(username_or_email)

        if user
          render_json_dump BasicUserSerializer.new(user, scope: guardian, root: 'user')
        else
          render json: success_json
        end
      else
        json = failed_json

        unless topic.private_message?
          group_names = topic.category
            .visible_group_names(current_user)
            .where(automatic: false)
            .pluck(:name)
            .join(", ")

          if group_names.present?
            json.merge!(errors: [
              I18n.t("topic_invite.failed_to_invite",
                group_names: group_names
              )
            ])
          end
        end

        render json: json, status: 422
      end
    rescue Topic::UserExists => e
      render json: { errors: [e.message] }, status: 422
    end
  end

  def set_notifications
    topic = Topic.find(params[:topic_id].to_i)
    TopicUser.change(current_user, topic.id, notification_level: params[:notification_level].to_i)
    render json: success_json
  end

  def merge_topic
    topic_id = params.require(:topic_id)
    destination_topic_id = params.require(:destination_topic_id)
    params.permit(:participants)
    params.permit(:archetype)

    raise Discourse::InvalidAccess if params[:archetype] == "private_message" && !guardian.is_staff?

    topic = Topic.find_by(id: topic_id)
    guardian.ensure_can_move_posts!(topic)

    args = {}
    args[:destination_topic_id] = destination_topic_id.to_i

    if params[:archetype].present?
      args[:archetype] = params[:archetype]
      args[:participants] = params[:participants] if params[:participants].present? && params[:archetype] == "private_message"
    end

    destination_topic = topic.move_posts(current_user, topic.posts.pluck(:id), args)
    render_topic_changes(destination_topic)
  end

  def move_posts
    post_ids = params.require(:post_ids)
    topic_id = params.require(:topic_id)
    params.permit(:category_id)
    params.permit(:tags)
    params.permit(:participants)
    params.permit(:archetype)

    raise Discourse::InvalidAccess if params[:archetype] == "private_message" && !guardian.is_staff?

    topic = Topic.with_deleted.find_by(id: topic_id)
    guardian.ensure_can_move_posts!(topic)

    # when creating a new topic, ensure the 1st post is a regular post
    if params[:title].present? && Post.where(topic: topic, id: post_ids).order(:post_number).pluck(:post_type).first != Post.types[:regular]
      return render_json_error("When moving posts to a new topic, the first post must be a regular post.")
    end

    destination_topic = move_posts_to_destination(topic)
    render_topic_changes(destination_topic)
  rescue ActiveRecord::RecordInvalid => ex
    render_json_error(ex)
  end

  def change_post_owners
    params.require(:post_ids)
    params.require(:topic_id)
    params.require(:username)

    guardian.ensure_can_change_post_owner!

    begin
      PostOwnerChanger.new(post_ids: params[:post_ids].to_a,
                           topic_id: params[:topic_id].to_i,
                           new_owner: User.find_by(username: params[:username]),
                           acting_user: current_user).change_owner!
      render json: success_json
    rescue ArgumentError
      render json: failed_json, status: 422
    end
  end

  def change_timestamps
    topic_id = params.require(:topic_id).to_i
    timestamp = params.require(:timestamp).to_f

    guardian.ensure_can_change_post_timestamps!

    topic = Topic.with_deleted.find(topic_id)
    previous_timestamp = topic.first_post.created_at

    begin
      TopicTimestampChanger.new(
        topic: topic,
        timestamp: timestamp
      ).change!

      StaffActionLogger.new(current_user).log_topic_timestamps_changed(topic, Time.zone.at(timestamp), previous_timestamp)

      render json: success_json
    rescue ActiveRecord::RecordInvalid, TopicTimestampChanger::InvalidTimestampError
      render json: failed_json, status: 422
    end
  end

  def clear_pin
    topic = Topic.find_by(id: params[:topic_id].to_i)
    guardian.ensure_can_see!(topic)
    topic.clear_pin_for(current_user)
    render body: nil
  end

  def re_pin
    topic = Topic.find_by(id: params[:topic_id].to_i)
    guardian.ensure_can_see!(topic)
    topic.re_pin_for(current_user)
    render body: nil
  end

  def timings
    allowed_params = topic_params

    topic_id = allowed_params[:topic_id].to_i
    topic_time = allowed_params[:topic_time].to_i
    timings = allowed_params[:timings].to_h || {}

    # ensure we capture current user for the block
    user = current_user

    hijack do
      PostTiming.process_timings(
        user,
        topic_id,
        topic_time,
        timings.map { |post_number, t| [post_number.to_i, t.to_i] },
        mobile: view_context.mobile_view?
      )
      render body: nil
    end
  end

  def feed
    @topic_view = TopicView.new(params[:topic_id])
    discourse_expires_in 1.minute
    render 'topics/show', formats: [:rss]
  end

  def bulk
    if params[:topic_ids].present?
      topic_ids = params[:topic_ids].map { |t| t.to_i }
    elsif params[:filter] == 'unread'
      tq = TopicQuery.new(current_user)
      topics = TopicQuery.unread_filter(tq.joined_topic_user, current_user.id, staff: guardian.is_staff?).listable_topics

      if params[:category_id]
        if params[:include_subcategories]
          topics = topics.where(<<~SQL, category_id: params[:category_id])
            category_id in (select id FROM categories WHERE parent_category_id = :category_id) OR
            category_id = :category_id
          SQL
        else
          topics = topics.where('category_id = ?', params[:category_id])
        end
      end
      topic_ids = topics.pluck(:id)
    else
      raise ActionController::ParameterMissing.new(:topic_ids)
    end

    operation = params
      .require(:operation)
      .permit(:type, :group, :category_id, :notification_level_id, tags: [])
      .to_h.symbolize_keys

    raise ActionController::ParameterMissing.new(:operation_type) if operation[:type].blank?
    operator = TopicsBulkAction.new(current_user, topic_ids, operation, group: operation[:group])
    changed_topic_ids = operator.perform!
    render_json_dump topic_ids: changed_topic_ids
  end

  def reset_new
    current_user.user_stat.update_column(:new_since, Time.now)
    render body: nil
  end

  def convert_topic
    params.require(:id)
    params.require(:type)
    topic = Topic.find_by(id: params[:id])
    guardian.ensure_can_convert_topic!(topic)

    if params[:type] == "public"
      converted_topic = topic.convert_to_public_topic(current_user, category_id: params[:category_id])
    else
      converted_topic = topic.convert_to_private_message(current_user)
    end
    render_topic_changes(converted_topic)
  rescue ActiveRecord::RecordInvalid => ex
    render_json_error(ex)
  end

  def reset_bump_date
    params.require(:id)
    guardian.ensure_can_update_bumped_at!

    topic = Topic.find_by(id: params[:id])
    raise Discourse::NotFound.new unless topic

    topic.reset_bumped_at
    render body: nil
  end

  private

  def topic_params
    params.permit(
      :topic_id,
      :topic_time,
      timings: {}
    )
  end

  def fetch_topic_view(options)
    if (username_filters = params[:username_filters]).present?
      options[:username_filters] = username_filters.split(',')
    end

    @topic_view = TopicView.new(params[:topic_id], current_user, options)
  end

  def toggle_mute
    @topic = Topic.find_by(id: params[:topic_id].to_i)
    guardian.ensure_can_see!(@topic)

    @topic.toggle_mute(current_user)
    render body: nil
  end

  def consider_user_for_promotion
    Promotion.new(current_user).review if current_user.present?
  end

  def slugs_do_not_match
    params[:slug] && @topic_view.topic.slug != params[:slug]
  end

  def redirect_to_correct_topic(topic, post_number = nil)
    url = topic.relative_url
    url << "/#{post_number}" if post_number.to_i > 0
    url << ".json" if request.format.json?

    page = params[:page]
    url << "?page=#{page}" if page != 0

    redirect_to url, status: 301
  end

  def track_visit_to_topic
    topic_id =  @topic_view.topic.id
    ip = request.remote_ip
    user_id = (current_user.id if current_user)
    track_visit = should_track_visit_to_topic?

    if !request.format.json?
      hash = {
        referer: request.referer || flash[:referer],
        host: request.host,
        current_user: current_user,
        topic_id: @topic_view.topic.id,
        post_number: @topic_view.current_post_number,
        username: request['u'],
        ip_address: request.remote_ip
      }
      # defer this way so we do not capture the whole controller
      # in the closure
      TopicsController.defer_add_incoming_link(hash)
    end

    TopicsController.defer_track_visit(topic_id, ip, user_id, track_visit)
  end

  def self.defer_track_visit(topic_id, ip, user_id, track_visit)
    Scheduler::Defer.later "Track Visit" do
      TopicViewItem.add(topic_id, ip, user_id)
      TopicUser.track_visit!(topic_id, user_id) if track_visit
    end
  end

  def self.defer_add_incoming_link(hash)
    Scheduler::Defer.later "Track Link" do
      IncomingLink.add(hash)
    end
  end

  def should_track_visit_to_topic?
    !!((!request.format.json? || params[:track_visit]) && current_user)
  end

  def perform_show_response

    if request.head?
      head :ok
      return
    end

    topic_view_serializer = TopicViewSerializer.new(@topic_view,
      scope: guardian,
      root: false,
      include_raw: !!params[:include_raw]
    )

    respond_to do |format|
      format.html do
        @description_meta = @topic_view.topic.excerpt.present? ? @topic_view.topic.excerpt : @topic_view.summary
        store_preloaded("topic_#{@topic_view.topic.id}", MultiJson.dump(topic_view_serializer))
        render :show
      end

      format.json do
        render_json_dump(topic_view_serializer)
      end
    end
  end

  def perform_hidden_topic_show_response(topic)
    respond_to do |format|
      format.html do
        @topic_view = nil
        render :show
      end

      format.json do
        render_serialized(topic, HiddenTopicViewSerializer, root: false)
      end
    end
  end

  def render_topic_changes(dest_topic)
    if dest_topic.present?
      render json: { success: true, url: dest_topic.relative_url }
    else
      render json: { success: false }
    end
  end

  def move_posts_to_destination(topic)
    args = {}
    args[:title] = params[:title] if params[:title].present?
    args[:destination_topic_id] = params[:destination_topic_id].to_i if params[:destination_topic_id].present?
    args[:tags] = params[:tags] if params[:tags].present?

    if params[:archetype].present?
      args[:archetype] = params[:archetype]
      args[:participants] = params[:participants] if params[:participants].present? && params[:archetype] == "private_message"
    else
      args[:category_id] = params[:category_id].to_i if params[:category_id].present?
    end

    topic.move_posts(current_user, post_ids_including_replies, args)
  end

  def check_for_status_presence(key, attr)
    invalid_param(key) unless %w(pinned pinned_globally visible closed archived).include?(attr)
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

  def pm_has_slots?(pm)
    guardian.is_staff? || !pm.reached_recipients_limit?
  end
end

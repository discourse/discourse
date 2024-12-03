# frozen_string_literal: true

class TopicsController < ApplicationController
  requires_login only: %i[
                   timings
                   destroy_timings
                   update
                   update_shared_draft
                   destroy
                   recover
                   status
                   invite
                   mute
                   unmute
                   set_notifications
                   move_posts
                   merge_topic
                   clear_pin
                   re_pin
                   status_update
                   timer
                   bulk
                   reset_new
                   change_post_owners
                   change_timestamps
                   archive_message
                   move_to_inbox
                   convert_topic
                   bookmark
                   publish
                   reset_bump_date
                   set_slow_mode
                 ]

  before_action :consider_user_for_promotion, only: :show

  skip_before_action :check_xhr, only: %i[show feed]

  def id_for_slug
    topic = Topic.find_by_slug(params[:slug])
    guardian.ensure_can_see!(topic)
    raise Discourse::NotFound unless topic
    render json: { slug: topic.slug, topic_id: topic.id, url: topic.url }
  end

  def show_by_external_id
    topic = Topic.find_by(external_id: params[:external_id])
    raise Discourse::NotFound unless topic
    guardian.ensure_can_see!(topic)
    redirect_to_correct_topic(topic, params[:post_number])
  end

  def show
    if params[:id].is_a?(Array) || params[:id].is_a?(ActionController::Parameters)
      raise Discourse::InvalidParameters.new("Show only accepts a single ID")
    end

    flash["referer"] ||= request.referer[0..255] if request.referer

    # TODO: We'd like to migrate the wordpress feed to another url. This keeps up backwards
    # compatibility with existing installs.
    return wordpress if params[:best].present?

    # work around people somehow sending in arrays,
    # arrays are not supported
    params[:page] = begin
      params[:page].to_i
    rescue StandardError
      1
    end

    opts =
      params.slice(
        :username_filters,
        :filter,
        :page,
        :post_number,
        :show_deleted,
        :replies_to_post_number,
        :filter_upwards_post_id,
        :filter_top_level_replies,
      )
    username_filters = opts[:username_filters]

    opts[:print] = true if params[:print] == "true"
    opts[:username_filters] = username_filters.split(",") if username_filters.is_a?(String)

    # Special case: a slug with a number in front should look by slug first before looking
    # up that particular number
    if params[:id] && params[:id] =~ /\A\d+[^\d\\]+\z/
      topic = Topic.find_by_slug(params[:id])
      return redirect_to_correct_topic(topic, opts[:post_number]) if topic
    end

    if opts[:print]
      raise Discourse::InvalidAccess if SiteSetting.max_prints_per_hour_per_user.zero?
      begin
        unless @guardian.is_admin?
          RateLimiter.new(
            current_user,
            "print-topic-per-hour",
            SiteSetting.max_prints_per_hour_per_user,
            1.hour,
          ).performed!
        end
      rescue RateLimiter::LimitExceeded
        return render_json_error I18n.t("rate_limiter.slow_down")
      end
    end

    begin
      @topic_view = TopicView.new(params[:id] || params[:topic_id], current_user, opts)
    rescue Discourse::NotFound => ex
      if params[:id]
        topic = Topic.find_by_slug(params[:id])
        return redirect_to_correct_topic(topic, opts[:post_number]) if topic
      end

      raise ex
    rescue Discourse::NotLoggedIn => ex
      raise(SiteSetting.detailed_404 ? ex : Discourse::NotFound)
    rescue Discourse::InvalidAccess => ex
      # If the user can't see the topic, clean up notifications for it.
      Notification.remove_for(current_user.id, params[:topic_id]) if current_user

      deleted =
        guardian.can_see_topic?(ex.obj, false) ||
          (!guardian.can_see_topic?(ex.obj) && ex.obj&.access_topic_via_group && ex.obj.deleted_at)

      if SiteSetting.detailed_404
        if deleted
          raise Discourse::NotFound.new(
                  "deleted topic",
                  custom_message: "deleted_topic",
                  status: 410,
                  check_permalinks: true,
                  original_path: ex.obj.relative_url,
                )
        elsif !guardian.can_see_topic?(ex.obj) && group = ex.obj&.access_topic_via_group
          raise Discourse::InvalidAccess.new(
                  "not in group",
                  ex.obj,
                  custom_message: "not_in_group.title_topic",
                  custom_message_params: {
                    group: group.name,
                  },
                  group: serialize_data(group, BasicGroupSerializer, root: false),
                )
        end

        raise ex
      else
        raise Discourse::NotFound.new(
                nil,
                check_permalinks: deleted,
                original_path: ex.obj.relative_url,
              )
      end
    end

    page = params[:page]
    if (page < 0) || ((page - 1) * @topic_view.chunk_size >= @topic_view.topic.highest_post_number)
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

    response.headers["X-Robots-Tag"] = "noindex" unless @topic_view.topic.visible

    canonical_url UrlHelper.absolute_without_cdn(@topic_view.canonical_path)

    # provide hint to crawlers only for now
    # we would like to give them a bit more signal about age of data
    if use_crawler_layout?
      if last_modified = @topic_view.posts&.map { |p| p.updated_at }&.max&.httpdate
        response.headers["Last-Modified"] = last_modified
      end
    end

    perform_show_response
  end

  def publish
    params.permit(:id, :destination_category_id)

    topic = Topic.find(params[:id])
    category = Category.find(params[:destination_category_id])

    raise Discourse::InvalidParameters if category.id == SiteSetting.shared_drafts_category.to_i

    guardian.ensure_can_publish_topic!(topic, category)
    topic = TopicPublisher.new(topic, current_user, category.id).publish!

    render_serialized(topic.reload, BasicTopicSerializer)
  end

  def wordpress
    params.require(:best)
    params.require(:topic_id)
    params.permit(
      :min_trust_level,
      :min_score,
      :min_replies,
      :bypass_trust_level_score,
      :only_moderator_liked,
    )

    begin
      opts = {
        best: params[:best].to_i,
        min_trust_level: params[:min_trust_level] ? params[:min_trust_level].to_i : 1,
        min_score: params[:min_score].to_i,
        min_replies: params[:min_replies].to_i,
        bypass_trust_level_score: params[:bypass_trust_level_score].to_i, # safe cause 0 means ignore
        only_moderator_liked: params[:only_moderator_liked].to_s == "true",
        exclude_hidden: true,
      }
    rescue NoMethodError
      raise Discourse::InvalidParameters
    end

    @topic_view = TopicView.new(params[:topic_id], current_user, opts)
    discourse_expires_in 1.minute

    wordpress_serializer =
      TopicViewWordpressSerializer.new(@topic_view, scope: guardian, root: false)
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
      skip_custom_fields: true,
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

    render_json_dump(
      TopicViewPostsSerializer.new(
        @topic_view,
        scope: guardian,
        root: false,
        include_raw: !!params[:include_raw],
      ),
    )
  end

  def excerpts
    params.require(:topic_id)
    params.require(:post_ids)

    unless Array === params[:post_ids]
      render_json_error("Expecting post_ids to contain a list of posts ids")
      return
    end
    post_ids = params[:post_ids].map(&:to_i)

    if post_ids.length > 100
      render_json_error("Requested a chunk that is too big")
      return
    end

    @topic = Topic.with_deleted.where(id: params[:topic_id]).first
    guardian.ensure_can_see!(@topic)

    @posts =
      Post
        .where(hidden: false, deleted_at: nil, topic_id: @topic.id)
        .where("posts.id in (?)", post_ids)
        .joins("LEFT JOIN users u on u.id = posts.user_id")
        .pluck(:id, :cooked, :username, :action_code, :created_at)
        .map do |post_id, cooked, username, action_code, created_at|
          attrs = {
            post_id: post_id,
            username: username,
            excerpt: PrettyText.excerpt(cooked, 800, keep_emoji_images: true),
          }

          if action_code
            attrs[:action_code] = action_code
            attrs[:created_at] = created_at
          end

          attrs
        end

    render json: @posts.to_json
  end

  def destroy_timings
    topic_id = params[:topic_id].to_i

    if params[:last].to_s == "1"
      PostTiming.destroy_last_for(current_user, topic_id: topic_id)
    else
      PostTiming.destroy_for(current_user.id, [topic_id])
    end

    last_notification =
      Notification
        .where(user_id: current_user.id, topic_id: topic_id)
        .order(created_at: :desc)
        .limit(1)
        .first

    last_notification.update!(read: false) if last_notification

    render body: nil
  end

  def update_shared_draft
    topic = Topic.find_by(id: params[:id])
    guardian.ensure_can_edit!(topic)

    category = Category.find_by(id: params[:category_id].to_i)
    guardian.ensure_can_publish_topic!(topic, category)

    row_count = SharedDraft.where(topic_id: topic.id).update_all(category_id: category.id)
    SharedDraft.create(topic_id: topic.id, category_id: category.id) if row_count == 0

    render json: success_json
  end

  def update
    topic = Topic.find_by(id: params[:topic_id])

    guardian.ensure_can_edit!(topic)

    original_title = params[:original_title]
    if original_title.present? && original_title != topic.title
      return render_json_error(I18n.t("edit_conflict"), status: 409)
    end

    original_tags = params[:original_tags]
    if original_tags.present? && original_tags.sort != topic.tags.pluck(:name).sort
      return render_json_error(I18n.t("edit_conflict"), status: 409)
    end

    if params[:category_id] && (params[:category_id].to_i != topic.category_id.to_i)
      if topic.shared_draft
        topic.shared_draft.update(category_id: params[:category_id])
        params.delete(:category_id)
      else
        category = Category.find_by(id: params[:category_id])

        if category || (params[:category_id].to_i == 0)
          begin
            guardian.ensure_can_move_topic_to_category!(category)
          rescue Discourse::InvalidAccess
            return(
              render_json_error I18n.t("category.errors.move_topic_to_category_disallowed"),
                                status: :forbidden
            )
          end
        else
          return render_json_error(I18n.t("category.errors.not_found"))
        end

        if category &&
             topic_tags = (params[:tags] || topic.tags.pluck(:name)).reject { |c| c.empty? }
          if topic_tags.present?
            allowed_tags =
              DiscourseTagging.filter_allowed_tags(guardian, category: category).map(&:name)

            invalid_tags = topic_tags - allowed_tags

            # Do not raise an error on a topic's hidden tags when not modifying tags
            if params[:tags].blank?
              invalid_tags.each do |tag_name|
                if DiscourseTagging.hidden_tag_names.include?(tag_name)
                  invalid_tags.delete(tag_name)
                end
              end
            end

            invalid_tags = Tag.where_name(invalid_tags).pluck(:name)

            if !invalid_tags.empty?
              if (invalid_tags & DiscourseTagging.hidden_tag_names).present?
                return render_json_error(I18n.t("category.errors.disallowed_tags_generic"))
              else
                return(
                  render_json_error(
                    I18n.t("category.errors.disallowed_topic_tags", tags: invalid_tags.join(", ")),
                  )
                )
              end
            end
          end
        end
      end
    end

    changes = {}

    PostRevisor.tracked_topic_fields.each_key { |f| changes[f] = params[f] if params.has_key?(f) }

    changes.delete(:title) if topic.title == changes[:title]
    changes.delete(:category_id) if topic.category_id.to_i == changes[:category_id].to_i

    if Tag.include_tags?
      topic_tags = topic.tags.map(&:name).sort
      changes.delete(:tags) if changes[:tags]&.sort == topic_tags
    end

    success = true

    if changes.length > 0
      bypass_bump = should_bypass_bump?(changes)

      first_post = topic.ordered_posts.first
      success =
        PostRevisor.new(first_post, topic).revise!(
          current_user,
          changes,
          validate_post: false,
          bypass_bump: bypass_bump,
          keep_existing_draft: params[:keep_existing_draft].to_s == "true",
        )

      topic.errors.add(:base, :unable_to_update) if !success && topic.errors.blank?
    end

    # this is used to return the title to the client as it may have been changed by "TextCleaner"
    success ? render_serialized(topic, BasicTopicSerializer) : render_json_error(topic)
  end

  def update_tags
    params.require(:tags)
    topic = Topic.find_by(id: params[:topic_id])
    guardian.ensure_can_edit_tags!(topic)

    success =
      PostRevisor.new(topic.first_post, topic).revise!(
        current_user,
        { tags: params[:tags] },
        validate_post: false,
      )

    success ? render_serialized(topic, BasicTopicSerializer) : render_json_error(topic)
  end

  def feature_stats
    params.require(:category_id)
    category_id = params[:category_id].to_i

    visible_topics = Topic.listable_topics.visible

    render json: {
             pinned_in_category_count:
               visible_topics
                 .where(category_id: category_id)
                 .where(pinned_globally: false)
                 .where.not(pinned_at: nil)
                 .count,
             pinned_globally_count:
               visible_topics.where(pinned_globally: true).where.not(pinned_at: nil).count,
             banner_count: Topic.listable_topics.where(archetype: Archetype.banner).count,
           }
  end

  def status
    params.require(:status)
    params.require(:enabled)
    params.permit(:until)

    status = params[:status]
    topic_id = params[:topic_id].to_i
    enabled = params[:enabled] == "true"

    check_for_status_presence(:status, status)
    @topic =
      if params[:category_id]
        Topic.find_by(id: topic_id, category_id: params[:category_id].to_i)
      else
        Topic.find_by(id: topic_id)
      end

    status_opts = { until: params[:until].presence }

    if status == "visible"
      status_opts[:visibility_reason_id] = (
        if enabled
          Topic.visibility_reasons[:manually_relisted]
        else
          Topic.visibility_reasons[:manually_unlisted]
        end
      )
    end

    case status
    when "closed"
      guardian.ensure_can_close_topic!(@topic)
    when "archived"
      guardian.ensure_can_archive_topic!(@topic)
    when "visible"
      guardian.ensure_can_toggle_topic_visibility!(@topic)
    when "pinned"
      guardian.ensure_can_pin_unpin_topic!(@topic)
    else
      guardian.ensure_can_moderate!(@topic)
    end

    @topic.update_status(status, enabled, current_user, status_opts)

    render json:
             success_json.merge!(
               topic_status_update:
                 TopicTimerSerializer.new(TopicTimer.find_by(topic: @topic), root: false),
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
      rescue StandardError
        invalid_param(:status_type)
      end
    based_on_last_post = params[:based_on_last_post]
    params.require(:duration_minutes) if based_on_last_post

    topic = Topic.find_by(id: params[:topic_id])
    guardian.ensure_can_moderate!(topic)

    guardian.ensure_can_delete!(topic) if TopicTimer.destructive_types.values.include?(status_type)

    options = { by_user: current_user, based_on_last_post: based_on_last_post }

    options.merge!(category_id: params[:category_id]) if !params[:category_id].blank?
    if params[:duration_minutes].present?
      options.merge!(duration_minutes: params[:duration_minutes].to_i)
    end
    options.merge!(duration: params[:duration].to_i) if params[:duration].present?

    begin
      topic_timer = topic.set_or_create_timer(status_type, params[:time], **options)
    rescue ActiveRecord::RecordInvalid => e
      return render_json_error(e.message)
    end

    if topic.save
      render json:
               success_json.merge!(
                 execute_at: topic_timer&.execute_at,
                 duration_minutes: topic_timer&.duration_minutes,
                 based_on_last_post: topic_timer&.based_on_last_post,
                 closed: topic.closed,
                 category_id: topic_timer&.category_id,
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
    BookmarkManager.new(current_user).destroy_for_topic(topic)
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
      allowed_groups =
        topic.allowed_groups.where("topic_allowed_groups.group_id IN (?)", group_ids).pluck(:id)

      allowed_groups.each do |id|
        if archive
          GroupArchivedMessage.archive!(id, topic, acting_user_id: current_user.id)

          group_id = id
        else
          GroupArchivedMessage.move_to_inbox!(id, topic, acting_user_id: current_user.id)
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

    bookmark_manager = BookmarkManager.new(current_user)
    bookmark_manager.create_for(bookmarkable_id: topic.id, bookmarkable_type: "Topic")

    return render_json_error(bookmark_manager, status: 400) if bookmark_manager.errors.any?

    render body: nil
  end

  def destroy
    topic = Topic.with_deleted.find_by(id: params[:id])
    force_destroy = ActiveModel::Type::Boolean.new.cast(params[:force_destroy])

    if force_destroy
      if !topic
        raise Discourse::InvalidAccess
      elsif !guardian.can_permanently_delete?(topic)
        return render_json_error topic.cannot_permanently_delete_reason(current_user), status: 403
      end
    else
      guardian.ensure_can_delete!(topic)
    end

    PostDestroyer.new(
      current_user,
      topic.ordered_posts.with_deleted.first,
      context: params[:context],
      force_destroy: force_destroy,
    ).destroy

    render body: nil
  rescue Discourse::InvalidAccess
    render_json_error I18n.t("delete_topic_failed")
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
    raise Discourse::NotFound if !group

    topic = Topic.find_by(id: params[:topic_id])
    raise Discourse::NotFound if !topic

    if !pm_has_slots?(topic)
      return(
        render_json_error(
          I18n.t(
            "pm_reached_recipients_limit",
            recipients_limit: SiteSetting.max_allowed_message_recipients,
          ),
        )
      )
    end

    if topic.private_message?
      guardian.ensure_can_invite_group_to_private_message!(group, topic)
      should_notify =
        if params[:should_notify].blank?
          true
        else
          params[:should_notify].to_s == "true"
        end
      topic.invite_group(current_user, group, should_notify: should_notify)
      render_json_dump BasicGroupSerializer.new(group, scope: guardian, root: "group")
    else
      render json: failed_json, status: 422
    end
  end

  def invite
    topic = Topic.find_by(id: params[:topic_id])
    raise Discourse::NotFound if !topic

    return render_json_error(I18n.t("topic_invite.not_pm")) if !topic.private_message?

    if !pm_has_slots?(topic)
      return(
        render_json_error(
          I18n.t(
            "pm_reached_recipients_limit",
            recipients_limit: SiteSetting.max_allowed_message_recipients,
          ),
        )
      )
    end

    guardian.ensure_can_invite_to!(topic)

    username_or_email = params[:user] ? fetch_username : fetch_email
    group_ids =
      Group.lookup_groups(group_ids: params[:group_ids], group_names: params[:group_names]).pluck(
        :id,
      )

    begin
      if topic.invite(current_user, username_or_email, group_ids, params[:custom_message])
        if user = User.find_by_username_or_email(username_or_email)
          render_json_dump BasicUserSerializer.new(user, scope: guardian, root: "user")
        else
          render json: success_json
        end
      else
        json = failed_json

        unless topic.private_message?
          group_names =
            topic
              .category
              .visible_group_names(current_user)
              .where(automatic: false)
              .pluck(:name)
              .join(", ")

          if group_names.present?
            json.merge!(errors: [I18n.t("topic_invite.failed_to_invite", group_names: group_names)])
          end
        end

        render json: json, status: 422
      end
    rescue Topic::UserExists, Topic::NotAllowed => e
      render json: { errors: [e.message] }, status: 422
    end
  end

  def set_notifications
    user =
      if is_api? && @guardian.is_admin? &&
           (params[:username].present? || params[:external_id].present?)
        fetch_user_from_params
      else
        current_user
      end

    topic = Topic.find(params[:topic_id].to_i)
    TopicUser.change(user, topic.id, notification_level: params[:notification_level].to_i)
    render json: success_json
  end

  def merge_topic
    topic_id = params.require(:topic_id)
    destination_topic_id = params.require(:destination_topic_id)
    params.permit(:participants)
    params.permit(:chronological_order)
    params.permit(:archetype)

    raise Discourse::InvalidAccess if params[:archetype] == "private_message" && !guardian.is_staff?

    topic = Topic.find_by(id: topic_id)
    guardian.ensure_can_move_posts!(topic)

    destination_topic = Topic.find_by(id: destination_topic_id)
    guardian.ensure_can_create_post_on_topic!(destination_topic)

    args = {}
    args[:destination_topic_id] = destination_topic_id.to_i
    args[:chronological_order] = params[:chronological_order] == "true"

    if params[:archetype].present?
      args[:archetype] = params[:archetype]
      args[:participants] = params[:participants] if params[:participants].present? &&
        params[:archetype] == "private_message"
    end

    acting_user = current_user
    hijack(info: "merging topic #{topic_id.inspect} into #{destination_topic_id.inspect}") do
      destination_topic = topic.move_posts(acting_user, topic.posts.pluck(:id), args)
      render_topic_changes(destination_topic)
    end
  end

  def move_posts
    post_ids = params.require(:post_ids)
    topic_id = params.require(:topic_id)
    params.permit(:category_id)
    params.permit(:tags)
    params.permit(:participants)
    params.permit(:chronological_order)
    params.permit(:archetype)

    topic = Topic.with_deleted.find_by(id: topic_id)
    guardian.ensure_can_move_posts!(topic)

    if params[:title].present?
      # when creating a new topic, ensure the 1st post is a regular post
      if Post.where(topic: topic, id: post_ids).order(:post_number).pick(:post_type) !=
           Post.types[:regular]
        return(
          render_json_error(
            "When moving posts to a new topic, the first post must be a regular post.",
          )
        )
      end

      if params[:category_id].present?
        guardian.ensure_can_create_topic_on_category!(params[:category_id])
      end
    end

    destination_topic = move_posts_to_destination(topic)
    render_topic_changes(destination_topic)
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => ex
    render_json_error(ex)
  end

  def change_post_owners
    params.require(:post_ids)
    params.require(:topic_id)
    params.require(:username)

    guardian.ensure_can_change_post_owner!

    begin
      PostOwnerChanger.new(
        post_ids: params[:post_ids].to_a,
        topic_id: params[:topic_id].to_i,
        new_owner: User.find_by(username: params[:username]),
        acting_user: current_user,
      ).change_owner!
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
      TopicTimestampChanger.new(topic: topic, timestamp: timestamp).change!

      StaffActionLogger.new(current_user).log_topic_timestamps_changed(
        topic,
        Time.zone.at(timestamp),
        previous_timestamp,
      )

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
        mobile: view_context.mobile_view?,
      )
      render body: nil
    end
  end

  def feed
    raise Discourse::NotFound if !Post.exists?(topic_id: params[:topic_id])

    begin
      @topic_view = TopicView.new(params[:topic_id])
    rescue Discourse::NotLoggedIn
      raise Discourse::NotFound
    rescue Discourse::InvalidAccess => ex
      deleted =
        guardian.can_see_topic?(ex.obj, false) ||
          (!guardian.can_see_topic?(ex.obj) && ex.obj&.access_topic_via_group && ex.obj.deleted_at)

      raise Discourse::NotFound.new(
              nil,
              check_permalinks: deleted,
              original_path: ex.obj.relative_url,
            )
    end

    discourse_expires_in 1.minute

    response.headers["X-Robots-Tag"] = "noindex, nofollow"
    render "topics/show", formats: [:rss]
  end

  def bulk
    if params[:topic_ids].present?
      unless Array === params[:topic_ids]
        raise Discourse::InvalidParameters.new("Expecting topic_ids to contain a list of topic ids")
      end
      topic_ids = params[:topic_ids].map { |t| t.to_i }
    elsif params[:filter] == "unread"
      topic_ids = bulk_unread_topic_ids
    else
      raise ActionController::ParameterMissing.new(:topic_ids)
    end

    operation =
      params
        .require(:operation)
        .permit(
          :type,
          :group,
          :category_id,
          :notification_level_id,
          :message,
          *DiscoursePluginRegistry.permitted_bulk_action_parameters,
          tags: [],
        )
        .to_h
        .symbolize_keys

    raise ActionController::ParameterMissing.new(:operation_type) if operation[:type].blank?

    operator = TopicsBulkAction.new(current_user, topic_ids, operation, group: operation[:group])
    hijack(info: "topics bulk action #{operation[:type]}") do
      changed_topic_ids = operator.perform!
      render_json_dump topic_ids: changed_topic_ids
    end
  end

  def private_message_reset_new
    topic_query = TopicQuery.new(current_user, limit: false)

    if params[:topic_ids].present?
      unless Array === params[:topic_ids]
        raise Discourse::InvalidParameters.new("Expecting topic_ids to contain a list of topic ids")
      end

      topic_scope =
        topic_query.private_messages_for(current_user, :all).where(
          "topics.id IN (?)",
          params[:topic_ids].map(&:to_i),
        )
    else
      params.require(:inbox)
      inbox = params[:inbox].to_s
      filter = private_message_filter(topic_query, inbox)
      topic_scope = topic_query.filter_private_message_new(current_user, filter)
    end

    topic_ids =
      TopicsBulkAction.new(current_user, topic_scope.pluck(:id), type: "dismiss_topics").perform!

    render json: success_json.merge(topic_ids: topic_ids)
  end

  def reset_new
    topic_scope =
      if current_user.new_new_view_enabled?
        if (params[:dismiss_topics] && params[:dismiss_posts])
          TopicQuery.new(current_user).new_and_unread_results(limit: false)
        elsif params[:dismiss_topics]
          TopicQuery.new(current_user).new_results(limit: false)
        elsif params[:dismiss_posts]
          TopicQuery.new(current_user).unread_results(limit: false)
        else
          Topic.none
        end
      else
        TopicQuery.new(current_user).new_results(limit: false)
      end
    if tag_name = params[:tag_id]
      tag_name = DiscourseTagging.visible_tags(guardian).where(name: tag_name).pluck(:name).first
    end

    topic_scope =
      if params[:category_id].present?
        category_id = params[:category_id].to_i

        category_ids =
          if ActiveModel::Type::Boolean.new.cast(params[:include_subcategories])
            Category.subcategory_ids(category_id)
          else
            [category_id]
          end

        category_ids &= guardian.allowed_category_ids
        if category_ids.blank?
          scope = topic_scope.none
        else
          scope = topic_scope.where(category_id: category_ids)
          scope = scope.joins(:tags).where(tags: { name: tag_name }) if tag_name
        end
        scope
      elsif tag_name.present?
        topic_scope.joins(:tags).where(tags: { name: tag_name })
      else
        if params[:tracked].to_s == "true"
          TopicQuery.tracked_filter(topic_scope, current_user.id)
        else
          current_user.user_stat.update_column(:new_since, Time.zone.now)
          topic_scope
        end
      end

    if params[:topic_ids].present?
      unless Array === params[:topic_ids]
        raise Discourse::InvalidParameters.new("Expecting topic_ids to contain a list of topic ids")
      end

      topic_ids = params[:topic_ids].map(&:to_i)
      topic_scope = topic_scope.where(id: topic_ids)
    end

    dismissed_topic_ids = []
    dismissed_post_topic_ids = []

    if !current_user.new_new_view_enabled? || params[:dismiss_topics]
      dismissed_topic_ids =
        TopicsBulkAction.new(current_user, topic_scope.pluck(:id), type: "dismiss_topics").perform!
    end

    if params[:dismiss_posts]
      if params[:untrack]
        dismissed_post_topic_ids =
          TopicsBulkAction.new(
            current_user,
            topic_scope.pluck(:id),
            type: "change_notification_level",
            notification_level_id: NotificationLevels.topic_levels[:regular],
          ).perform!
      else
        dismissed_post_topic_ids =
          TopicsBulkAction.new(current_user, topic_scope.pluck(:id), type: "dismiss_posts").perform!
      end
    end

    render_json_dump topic_ids: dismissed_topic_ids.concat(dismissed_post_topic_ids).uniq
  end

  def convert_topic
    params.require(:id)
    params.require(:type)

    topic = Topic.find_by(id: params[:id])
    guardian.ensure_can_convert_topic!(topic)

    topic =
      if params[:type] == "public"
        topic.convert_to_public_topic(current_user, category_id: params[:category_id])
      else
        topic.convert_to_private_message(current_user)
      end

    topic.valid? ? render_topic_changes(topic) : render_json_error(topic)
  end

  def reset_bump_date
    params.require(:id)
    params.permit(:post_id)

    guardian.ensure_can_update_bumped_at!

    topic = Topic.find_by(id: params[:id])
    raise Discourse::NotFound.new unless topic

    topic.reset_bumped_at(params[:post_id])
    render body: nil
  end

  def set_slow_mode
    topic = Topic.find(params[:topic_id])
    slow_mode_type = TopicTimer.types[:clear_slow_mode]
    timer = TopicTimer.find_by(topic: topic, status_type: slow_mode_type)

    guardian.ensure_can_moderate!(topic)
    topic.update!(slow_mode_seconds: params[:seconds])
    enabled = params[:seconds].to_i > 0

    time = enabled && params[:enabled_until].present? ? params[:enabled_until] : nil

    topic.set_or_create_timer(slow_mode_type, time, by_user: timer&.user)

    StaffActionLogger.new(current_user).log_topic_slow_mode(
      topic,
      enabled:,
      seconds: params[:seconds],
      until: time,
    )

    head :ok
  end

  private

  def topic_params
    params.permit(:topic_id, :topic_time, timings: {})
  end

  def fetch_topic_view(options)
    if (username_filters = params[:username_filters]).present?
      options[:username_filters] = username_filters.split(",")
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

  def should_bypass_bump?(changes)
    (changes[:category_id].present? && SiteSetting.disable_category_edit_notifications) ||
      (changes[:tags].present? && SiteSetting.disable_tags_edit_notifications)
  end

  def slugs_do_not_match
    if SiteSetting.slug_generation_method != "encoded"
      params[:slug] && @topic_view.topic.slug != params[:slug]
    else
      params[:slug] && CGI.unescape(@topic_view.topic.slug) != params[:slug]
    end
  end

  def redirect_to_correct_topic(topic, post_number = nil)
    begin
      guardian.ensure_can_see!(topic)
    rescue Discourse::InvalidAccess => ex
      raise(SiteSetting.detailed_404 ? ex : Discourse::NotFound)
    end

    # Allow plugins to append allowed query parameters, so they aren't scrubbed on redirect to proper topic URL
    additional_allowed_query_parameters =
      DiscoursePluginRegistry.apply_modifier(
        :redirect_to_correct_topic_additional_query_parameters,
        [],
      )

    opts =
      params.slice(
        *%i[page print filter_top_level_replies preview_theme_id].concat(
          additional_allowed_query_parameters,
        ),
      )
    opts.delete(:page) if params[:page] == 0

    url = topic.relative_url
    url << "/#{post_number}" if post_number.to_i > 0
    url << ".json" if request.format.json?

    opts.each do |k, v|
      s = url.include?("?") ? "&" : "?"
      url << "#{s}#{k}=#{v}"
    end

    redirect_to url, status: 301
  end

  def track_visit_to_topic
    topic_id = @topic_view.topic.id
    ip = request.remote_ip
    user_id = (current_user.id if current_user)

    if !request.format.json?
      hash = {
        referer: request.referer || flash[:referer],
        host: request.host,
        current_user: current_user,
        topic_id: @topic_view.topic.id,
        post_number: @topic_view.current_post_number,
        username: request["u"],
        ip_address: request.remote_ip,
      }
      # defer this way so we do not capture the whole controller
      # in the closure
      TopicsController.defer_add_incoming_link(hash)
    end

    TopicsController.defer_track_visit(topic_id, user_id) if should_track_visit_to_topic?
  end

  def self.defer_track_visit(topic_id, user_id)
    Scheduler::Defer.later "Track Visit" do
      TopicUser.track_visit!(topic_id, user_id)
    end
  end

  def self.defer_topic_view(topic_id, ip, user_id = nil)
    Scheduler::Defer.later "Topic View" do
      topic = Topic.find_by(id: topic_id)
      next if topic.blank?
      next if topic.shared_draft?

      # We need to make sure that we aren't allowing recording
      # random topic views against topics the user cannot see.
      user = User.find_by(id: user_id) if user_id.present?
      next if user_id.present? && user.blank?
      next if !Guardian.new(user).can_see_topic?(topic)

      TopicViewItem.add(topic_id, ip, user_id)
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

    if params[:replies_to_post_number] || params[:filter_upwards_post_id] ||
         params[:filter_top_level_replies] || @topic_view.next_page.present?
      @topic_view.include_suggested = false
      @topic_view.include_related = false
    end

    topic_view_serializer =
      TopicViewSerializer.new(
        @topic_view,
        scope: guardian,
        root: false,
        include_raw: !!params[:include_raw],
      )

    respond_to do |format|
      format.html do
        @tags = SiteSetting.tagging_enabled ? @topic_view.topic.tags.visible(guardian) : []
        @breadcrumbs = helpers.categories_breadcrumb(@topic_view.topic) || []
        @description_meta =
          @topic_view.topic.excerpt.present? ? @topic_view.topic.excerpt : @topic_view.summary
        store_preloaded("topic_#{@topic_view.topic.id}", MultiJson.dump(topic_view_serializer))
        render :show
      end

      format.json { render_json_dump(topic_view_serializer) }
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
    args[:destination_topic_id] = params[:destination_topic_id].to_i if params[
      :destination_topic_id
    ].present?
    args[:tags] = params[:tags] if params[:tags].present?
    args[:chronological_order] = params[:chronological_order] == "true"

    if params[:archetype].present?
      args[:archetype] = params[:archetype]
      args[:participants] = params[:participants] if params[:participants].present? &&
        params[:archetype] == "private_message"
    else
      args[:category_id] = params[:category_id].to_i if params[:category_id].present?
    end

    topic.move_posts(current_user, post_ids_including_replies, args)
  end

  def check_for_status_presence(key, attr)
    invalid_param(key) if %w[pinned pinned_globally visible closed archived].exclude?(attr)
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

  def bulk_unread_topic_ids
    topic_query = TopicQuery.new(current_user)

    if inbox = params[:private_message_inbox]
      filter = private_message_filter(topic_query, inbox)
      topic_query.options[:limit] = false
      topics = topic_query.filter_private_messages_unread(current_user, filter)
    else
      topics =
        TopicQuery.unread_filter(
          topic_query.joined_topic_user,
          whisperer: guardian.is_whisperer?,
        ).listable_topics

      topics = TopicQuery.tracked_filter(topics, current_user.id) if params[:tracked].to_s == "true"

      if params[:category_id]
        category_ids =
          if params[:include_subcategories]
            Category.subcategory_ids(params[:category_id].to_i)
          else
            params[:category_id]
          end

        topics = topics.where(category_id: category_ids)
      end

      if params[:tag_name].present?
        topics = topics.joins(:tags).where("tags.name": params[:tag_name])
      end
    end

    topics.pluck(:id)
  end

  def private_message_filter(topic_query, inbox)
    case inbox
    when "group"
      group_name = params[:group_name]
      group = Group.find_by("lower(name) = ?", group_name)
      raise Discourse::NotFound if !group
      raise Discourse::NotFound if !guardian.can_see_group_messages?(group)
      topic_query.options[:group_name] = group_name
      :group
    when "user"
      :user
    else
      :all
    end
  end
end

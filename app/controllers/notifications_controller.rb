# frozen_string_literal: true

class NotificationsController < ApplicationController
  requires_login
  before_action :ensure_admin, only: %i[create update destroy]
  before_action :set_notification, only: %i[update destroy]

  INDEX_LIMIT = 60
  MICROSECOND_DIGITS = 6
  MAX_ID = 2**63 - 1

  def index
    user =
      if params[:username] && !params[:recent]
        user_record = User.find_by(username: params[:username].to_s)
        raise Discourse::NotFound if !user_record
        user_record
      else
        current_user
      end

    guardian.ensure_can_see_notifications!(user)

    notification_types = notification_type_ids(:filter_by_types)

    if params[:recent].present?
      limit = fetch_limit_from_params(default: 15, max: INDEX_LIMIT)

      notifications = current_user.notification_feed.menu(limit:, types: notification_types)
      # notification_types is blank for the "all notifications" user menu tab
      include_reviewables = notification_types.blank? && guardian.can_see_review_queue?

      if notifications.present? && !(params.has_key?(:silent) || @readonly_mode)
        if current_user.bump_last_seen_notification!
          current_user.reload
          current_user.publish_notifications_state
        end
      end

      if !params.has_key?(:silent) && params[:bump_last_seen_reviewable] && !@readonly_mode &&
           include_reviewables
        current_user_id = current_user.id
        Scheduler::Defer.later "bump last seen reviewable for user" do
          # we lookup current_user again in the background thread to avoid
          # concurrency issues where the user object returned by the
          # current_user controller method is changed by the time the deferred
          # block is executed
          User.find_by(id: current_user_id)&.bump_last_seen_reviewable!
        end
      end

      notifications = Notification.populate_acting_user(notifications)

      json = {
        notifications: serialize_data(notifications, NotificationSerializer),
        seen_notification_id: current_user.seen_notification_id,
      }

      if include_reviewables
        json[:pending_reviewables] = Reviewable.basic_serializers_for_list(
          Reviewable.user_menu_list_for(current_user),
          current_user,
        ).as_json
      end

      render_json_dump(json)
    else
      raise Discourse::InvalidParameters.new(:offset) if params.has_key?(:offset)

      limit = fetch_limit_from_params(default: INDEX_LIMIT, max: INDEX_LIMIT)
      state = Notification::Feed::READ_STATES.keys.find { |name| name.to_s == params[:filter] }
      page =
        Notification::Feed.new(user, viewer: guardian).page(
          limit:,
          before: page_cursor,
          state:,
          types: notification_types,
        )
      notifications = Notification.populate_acting_user(page.notifications)

      json = {
        notifications: serialize_data(notifications, NotificationSerializer),
        seen_notification_id: user.seen_notification_id,
      }

      if page.cursor
        created_at, id = page.cursor
        json[:load_more_notifications] = notifications_path(
          username: user.username,
          before_created_at: created_at.iso8601(MICROSECOND_DIGITS),
          before_id: id,
          limit: limit,
          filter: state,
          filter_by_types: params[:filter_by_types],
        )
      end

      render_json_dump(json)
    end
  end

  def mark_read
    if params.has_key?(:id)
      Notification.read(current_user, [fetch_int_from_params(:id, default: nil)])
    else
      Notification.read_types(current_user, notification_type_ids(:dismiss_types))
      current_user.bump_last_seen_notification!
    end

    current_user.reload
    current_user.publish_notifications_state

    render json: success_json
  end

  def create
    @notification = Notification.consolidate_or_create!(notification_params)
    render_notification
  end

  def update
    @notification.update!(notification_params)
    render_notification
  end

  def destroy
    @notification.destroy!
    render json: success_json
  end

  def totals
    render_serialized(current_user, UserNotificationTotalSerializer, root: false)
  end

  private

  def notification_type_ids(param)
    return if !params.has_key?(param)

    names = params[param].to_s.split(",")
    raise Discourse::InvalidParameters.new(param) if names.blank?

    names.map do |name|
      Notification.types[name.to_sym] ||
        raise(Discourse::InvalidParameters.new("invalid notification type: #{name}"))
    end
  end

  def page_cursor
    return if params[:before_created_at].blank? && params[:before_id].blank?

    params.require(%i[before_created_at before_id])
    created_at = Time.zone.iso8601(params[:before_created_at].to_s)
    raise ArgumentError if !created_at.between?(Time.zone.at(0), 1.day.from_now)

    [created_at, fetch_int_from_params(:before_id, default: nil, min: 1, max: MAX_ID)]
  rescue ArgumentError
    raise Discourse::InvalidParameters.new(:before_created_at)
  end

  def set_notification
    @notification = Notification.find(params[:id])
  end

  def notification_params
    params.permit(
      :notification_type,
      :user_id,
      :data,
      :read,
      :topic_id,
      :post_number,
      :post_action_id,
    )
  end

  def render_notification
    render_json_dump(NotificationSerializer.new(@notification, scope: guardian, root: false))
  end
end

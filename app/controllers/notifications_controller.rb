# frozen_string_literal: true

class NotificationsController < ApplicationController
  requires_login
  before_action :ensure_admin, only: %i[create update destroy]
  before_action :set_notification, only: %i[update destroy]

  INDEX_LIMIT = 60

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
      limit = fetch_limit_from_params(default: INDEX_LIMIT, max: INDEX_LIMIT)
      offset = params[:offset].to_i
      state = Notification::Feed::READ_STATES.keys.find { |name| name.to_s == params[:filter] }

      notifications =
        Notification::Feed
          .new(user, viewer: guardian)
          .notifications(types: notification_types, state:)
          .includes(:topic)
          .order(created_at: :desc)

      total_rows = notifications.count
      notifications = notifications.offset(offset).limit(limit)

      notifications = Notification.populate_acting_user(notifications)
      render_json_dump(
        notifications: serialize_data(notifications, NotificationSerializer),
        total_rows_notifications: total_rows,
        seen_notification_id: user.seen_notification_id,
        load_more_notifications:
          notifications_path(
            username: user.username,
            offset: offset + limit,
            limit: limit,
            filter: params[:filter],
            filter_by_types: params[:filter_by_types].presence,
          ),
      )
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

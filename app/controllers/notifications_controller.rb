# frozen_string_literal: true

class NotificationsController < ApplicationController
  requires_login
  before_action :ensure_admin, only: %i[create update destroy]
  before_action :set_notification, only: %i[update destroy]

  INDEX_LIMIT = 60

  def index
    user =
      if params[:username].present? && params[:recent].blank?
        User.find_by_username(params[:username].to_s) || (raise Discourse::NotFound)
      else
        current_user
      end

    guardian.ensure_can_see_notifications!(user)

    if notification_types = params[:filter_by_types]&.split(",").presence
      notification_types.map! do |type|
        Notification.types[type.to_sym] ||
          (raise Discourse::InvalidParameters.new("invalid notification type: #{type}"))
      end
    end

    if params[:recent].present?
      limit = fetch_limit_from_params(default: 15, max: INDEX_LIMIT)

      notifications =
        Notification.prioritized_list(current_user, count: limit, types: notification_types)

      notifications =
        Notification.filter_inaccessible_topic_notifications(current_user.guardian, notifications)

      notifications =
        Notification.populate_acting_user(notifications) if SiteSetting.show_user_menu_avatars

      include_reviewables = notification_types.blank? && guardian.can_see_review_queue?
      bump_notification = notifications.present?
      bump_reviewable = include_reviewables && params[:bump_last_seen_reviewable]

      if !params.has_key?(:silent) && !@readonly_mode
        if bump_notification || bump_reviewable
          current_user_id = current_user.id
          Scheduler::Defer.later "bump last seen notification/reviewable for user" do
            if user = User.find_by(id: current_user_id)
              user.bump_last_seen_notification! if bump_notification
              user.bump_last_seen_reviewable! if bump_reviewable
            end
          end
        end
      end

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

      notifications = user.notifications.visible.includes(:topic).order(created_at: :desc)
      notifications = notifications.read if params[:filter] == "read"
      notifications = notifications.unread if params[:filter] == "unread"

      total_rows = notifications.dup.count

      notifications = notifications.offset(offset).limit(limit)

      notifications =
        Notification.filter_inaccessible_topic_notifications(current_user.guardian, notifications)

      notifications =
        Notification.populate_acting_user(notifications) if SiteSetting.show_user_menu_avatars

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
          ),
      )
    end
  end

  def mark_read
    if id = params[:id]
      Notification.read!(current_user, id:)
    else
      if types = params[:dismiss_types]&.split(",").presence
        types.map! do |type|
          Notification.types[type.to_sym] ||
            (raise Discourse::InvalidParameters.new("invalid notification type: #{type}"))
        end
      end

      Notification.read!(current_user, types:)
    end

    current_user.bump_last_seen_notification!

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

require_dependency 'push_notifications'

class PushNotificationsController < ApplicationController
  layout false
  before_filter :ensure_logged_in
  before_filter :set_endpoint, only: [:subscribe, :unsubscribe]
  skip_before_filter :preload_json

  def subscribe
    if @endpoint.start_with?(PushNotifications::GCM_ENDPOINT)
      PushNotifications.subscribe(current_user, @endpoint)
      render json: success_json
    else
      render json: failed_json
    end
  end

  def unsubscribe
    if @endpoint.start_with?(PushNotifications::GCM_ENDPOINT)
      PushNotifications.unsubscribe(current_user, @endpoint)
      render json: success_json
    else
      render json: failed_json
    end
  end

  def latest
    guardian.ensure_can_see_notifications!(current_user)

    notifications = Notification.where(user_id: current_user.id, read: false)
                                .visible
                                .includes(:topic)
                                .order(created_at: :desc)

    base_url = Discourse.base_url
    site_title = SiteSetting.title

    info =
      if notifications.count.many?
        { body: t('user_notifications.push.body', count: notifications.count) }
      else
        notification = notifications.first

        {
          title: notification.text_description { "\"#{notification.topic.title}\" - #{site_title}" },
          body: notification.topic.posts.find(notification.data_hash["original_post_id"]).excerpt(400, text_entities: true, strip_links: true),
          url: notification.topic.url(notification.post_number)
        }
      end

    render_json_dump({
      title: site_title,
      icon: "#{base_url}#{SiteSetting.logo_small_url || SiteSetting.logo_url}",
      url: base_url,
      tag: base_url
    }.merge(info))
  end

  private

  def set_endpoint
    @endpoint = params[:endpoint]
  end
end

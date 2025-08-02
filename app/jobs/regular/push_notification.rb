# frozen_string_literal: true

module Jobs
  class PushNotification < ::Jobs::Base
    def execute(args)
      user = User.find_by(id: args["user_id"])
      push_window = SiteSetting.push_notification_time_window_mins
      return if !user || (push_window > 0 && user.seen_since?(push_window.minutes.ago))

      notification = args["payload"]
      notification["url"] = UrlHelper.absolute_without_cdn(
        Discourse.base_path + notification["post_url"],
      )
      notification.delete("post_url")

      payload = {
        secret_key: SiteSetting.push_api_secret_key,
        url: Discourse.base_url,
        title: SiteSetting.title,
        description: SiteSetting.site_description,
      }

      clients = args["clients"]
      clients
        .group_by { |r| r[1] }
        .each do |push_url, group|
          notifications = group.map { |client_id, _| notification.merge(client_id: client_id) }

          next if push_url.blank?

          uri = URI.parse(push_url)

          http = FinalDestination::HTTP.new(uri.host, uri.port)
          http.use_ssl = uri.scheme == "https"

          request =
            FinalDestination::HTTP::Post.new(
              uri.request_uri,
              { "Content-Type" => "application/json" },
            )
          request.body = payload.merge(notifications: notifications).to_json

          begin
            response = http.request(request)

            if response.code.to_i != 200
              Rails.logger.warn(
                "Failed to push a notification to #{push_url} Status: #{response.code}: #{response.body}",
              )
            end
          rescue => e
            Rails.logger.error("An error occurred while pushing a notification: #{e.message}")
          end
        end
    end
  end
end

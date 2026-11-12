# frozen_string_literal: true

class HubPushNotificationPusher
  def self.push(user, payload)
    clients = UserApiKey.push_clients_for(user)
    return if clients.empty?

    notification = payload.dup
    notification["url"] = UrlHelper.absolute_without_cdn(
      Discourse.base_path + notification["post_url"],
    )
    notification.delete("post_url")

    hub_payload = {
      secret_key: SiteSetting.push_api_secret_key,
      url: Discourse.base_url,
      title: SiteSetting.title,
      description: SiteSetting.site_description,
    }

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
        request.body = hub_payload.merge(notifications: notifications).to_json

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

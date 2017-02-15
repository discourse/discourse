module Jobs
  class PushNotification < Jobs::Base
    def execute(args)
      notification = args["payload"]
      notification["url"] = UrlHelper.absolute_without_cdn(notification["post_url"])
      notification.delete("post_url")

      payload = {
        secret_key: SiteSetting.push_api_secret_key,
        url: Discourse.base_url,
        title: SiteSetting.title,
        description: SiteSetting.site_description,
      }

      clients = args["clients"]
      clients.group_by{|r| r[1]}.each do |push_url, group|
        notifications = group.map do |client_id, _|
          notification.merge({
            client_id: client_id
          })
        end

        RestClient.send :post, push_url, payload.merge({notifications: notifications}).to_json, content_type: :json, accept: :json

      end

    end
  end
end

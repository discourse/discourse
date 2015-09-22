class PushNotifications
  KEY_PREFIX = "push-notification-subscription:".freeze
  GCM_ENDPOINT = 'https://android.googleapis.com/gcm/send'.freeze

  def self.registration_ids(user)
    $redis.smembers(redis_key(user))
  end

  def self.subscribe(user, endpoint)
    $redis.sadd(redis_key(user), extract_registration_id(endpoint))
  end

  def self.unsubscribe(user, endpoint)
    $redis.srem(redis_key(user), extract_registration_id(endpoint))
  end

  def self.push(user)
    self.registration_ids(user).each do |registration_id|
      if !SiteSetting.gcm_api_key.blank?
        headers = {
          'Content-Type' => 'application/x-www-form-urlencoded;charset=UTF-8',
          'Authorization' => "key=#{SiteSetting.gcm_api_key}"
        }

        body = URI.encode_www_form(
          registration_id: registration_id,
          collapse_key: Discourse.base_url
        )

        result = Excon.post(GCM_ENDPOINT, headers: headers, body: body)

        if result.status == 200 && result.body.start_with?("Error")
          Rails.logger.error("There was an error from Google Cloud Message: #{result.body}")
        elsif result.status != 200
          Rails.logger.error("There was an error sending a request to Google Cloud Message: #{result.status}")
        end
      end
    end
  end

  private

  def self.redis_key(user)
    "#{KEY_PREFIX}#{user.id}"
  end

  def self.extract_registration_id(endpoint)
    endpoint_parts = endpoint.split("/")
    endpoint_parts[endpoint_parts.length - 1]
  end
end

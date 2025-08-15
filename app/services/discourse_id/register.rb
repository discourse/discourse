# frozen_string_literal: true

class DiscourseId::Register
  include Service::Base

  policy :discourse_id_enabled
  params { attribute :force, :boolean, default: false }

  step :validate_not_already_registered
  step :request_challenge
  step :store_challenge_token
  step :register_with_challenge
  step :store_credentials

  private

  def discourse_id_enabled
    SiteSetting.enable_discourse_id
  end

  def validate_not_already_registered
    return if context.force

    if SiteSetting.discourse_id_client_id.present? &&
         SiteSetting.discourse_id_client_secret.present?
      fail!(I18n.t("discourse_id.already_registered"))
    end
  end

  def request_challenge
    uri = URI("#{discourse_id_url}/challenge")

    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request.body = { domain: Discourse.current_hostname }.to_json

    response =
      Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(request)
      end

    fail!("Failed to request challenge: #{response.code}") unless response.code == "200"

    challenge_data = JSON.parse(response.body)
    context[:token] = challenge_data["token"]
  rescue => e
    fail!("Challenge request failed: #{e.message}")
  end

  def store_challenge_token(token:)
    Discourse.redis.setex("discourse_id_challenge_token", 600, token)
  end

  def register_with_challenge(token:)
    uri = URI("#{discourse_id_url}/register")

    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"

    request.body = {
      client_name: SiteSetting.title,
      redirect_uri: "#{Discourse.base_url}/auth/discourse_id/callback",
      challenge_token: token,
      logo_uri: SiteSetting.site_logo_url.presence,
      logo_small_uri: SiteSetting.site_logo_small_url.presence,
      description: SiteSetting.site_description.presence,
    }.compact.to_json

    response =
      Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(request)
      end

    fail!("Registration failed: #{response.code}") if response.code != "200"

    context[:data] = JSON.parse(response.body)
  rescue => e
    fail!("Registration request failed: #{e.message}")
  end

  def store_credentials(data:)
    SiteSetting.discourse_id_client_id = data["client_id"]
    SiteSetting.discourse_id_client_secret = data["client_secret"]

    Rails.logger.info("Successfully registered with Discourse ID: #{data["client_id"]}")
  end

  def discourse_id_url
    SiteSetting.discourse_id_provider_url.presence || "https://id.discourse.com"
  end
end

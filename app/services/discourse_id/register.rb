# frozen_string_literal: true

class DiscourseId::Register
  include Service::Base

  params do
    attribute :force, :boolean, default: false
    attribute :discourse_login_api_key, :string, default: nil
  end

  policy :not_already_registered?
  step :request_challenge
  step :store_challenge_token
  step :register
  step :store_credentials
  step :enable_discourse_id

  private

  def not_already_registered?(params:)
    return true if params.force

    SiteSetting.discourse_id_client_id.blank? && SiteSetting.discourse_id_client_secret.blank?
  end

  def request_challenge(params:)
    if params.discourse_login_api_key.present?
      context[:token] = nil
      return true
    end

    uri = URI("#{discourse_id_url}/challenge")
    use_ssl = Rails.env.production? || uri.scheme == "https"

    request = Net::HTTP::Post.new(uri)
    request.content_type = "application/json"
    request.body = { domain: Discourse.current_hostname }.to_json

    begin
      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl:) { |http| http.request(request) }
    rescue StandardError => e
      return fail!(error: "Challenge request failed: #{e.message}")
    end

    if response.code.to_i != 200
      return fail!(error: "Failed to request challenge: #{response.code}\nError: #{response.body}")
    end

    begin
      json = JSON.parse(response.body)
    rescue JSON::ParserError => e
      return fail!(error: "Challenge response invalid JSON: #{e.message}")
    end

    if json["domain"] != Discourse.current_hostname
      return fail!(error: "Domain mismatch in challenge response")
    end

    context[:token] = json["token"]
  end

  def store_challenge_token(params:, token:)
    return true if params.discourse_login_api_key.present?

    Discourse.redis.setex("discourse_id_challenge_token", 600, token)
  end

  def register(params:, token:)
    uri = URI("#{discourse_id_url}/register")
    use_ssl = Rails.env.production? || uri.scheme == "https"

    request = Net::HTTP::Post.new(uri)
    request.content_type = "application/json"
    request[
      "Discourse-Login-Api-Key"
    ] = params.discourse_login_api_key if params.discourse_login_api_key.present?
    request.body = {
      client_name: SiteSetting.title,
      redirect_uri: "#{Discourse.base_url}/auth/discourse_id/callback",
      challenge_token: token.presence,
      logo_uri: SiteSetting.site_logo_url.presence,
      logo_small_uri: SiteSetting.site_logo_small_url.presence,
      description: SiteSetting.site_description.presence,
    }.compact.to_json

    begin
      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl:) { |http| http.request(request) }
    rescue StandardError => e
      return fail!(error: "Registration request failed: #{e.message}")
    end

    if response.code.to_i != 200
      return fail!(error: "Registration failed: #{response.code}\nError: #{response.body}")
    end

    begin
      context[:data] = JSON.parse(response.body)
    rescue JSON::ParserError => e
      fail!(error: "Registration response invalid JSON: #{e.message}")
    end
  end

  def store_credentials(data:)
    SiteSetting.discourse_id_client_id = data["client_id"]
    SiteSetting.discourse_id_client_secret = data["client_secret"]
  end

  def enable_discourse_id
    SiteSetting.enable_discourse_id = true
  end

  def discourse_id_url
    SiteSetting.discourse_id_provider_url.presence || "https://id.discourse.com"
  end
end

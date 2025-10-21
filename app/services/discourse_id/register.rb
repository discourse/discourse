# frozen_string_literal: true

class DiscourseId::Register
  include Service::Base

  params { attribute :force, :boolean, default: false }

  policy :not_already_registered?
  step :request_challenge
  step :store_challenge_token
  step :register_with_challenge
  step :store_credentials

  private

  def not_already_registered?(params:)
    return true if params.force

    SiteSetting.discourse_id_client_id.blank? && SiteSetting.discourse_id_client_secret.blank?
  end

  def request_challenge
    uri = URI("#{discourse_id_url}/challenge")
    use_ssl = Rails.env.production? || uri.scheme == "https"

    body = { domain: Discourse.current_hostname }
    body[:path] = Discourse.base_path if Discourse.base_path.present?

    request = Net::HTTP::Post.new(uri)
    request.content_type = "application/json"
    request.body = body.to_json

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

    if Discourse.base_path.present? && json["path"] != Discourse.base_path
      return fail!(error: "Path mismatch in challenge response")
    end

    context[:token] = json["token"]
  end

  def store_challenge_token(token:)
    Discourse.redis.setex("discourse_id_challenge_token", 600, token)
  end

  def register_with_challenge(token:)
    uri = URI("#{discourse_id_url}/register")
    use_ssl = Rails.env.production? || uri.scheme == "https"

    request = Net::HTTP::Post.new(uri)
    request.content_type = "application/json"
    request.body = {
      client_name: SiteSetting.title,
      redirect_uri: "#{Discourse.base_url}/auth/discourse_id/callback",
      challenge_token: token,
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

  def discourse_id_url
    @url ||= SiteSetting.discourse_id_provider_url.presence || "https://id.discourse.com"
  end
end

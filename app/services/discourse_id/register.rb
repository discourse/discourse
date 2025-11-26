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
      error = "Challenge request to '#{uri}' failed: #{e.message}."
      log_error("request_challenge", error)
      return fail!(error:)
    end

    if response.code.to_i != 200
      error = "Failed to request challenge: #{response.code}\nError: #{response.body}"
      log_error("request_challenge", error)
      return fail!(error:)
    end

    begin
      json = JSON.parse(response.body)
    rescue JSON::ParserError => e
      error = "Challenge response invalid JSON: #{e.message}"
      log_error("request_challenge", error)
      return fail!(error:)
    end

    if json["domain"] != Discourse.current_hostname
      error =
        "Domain mismatch in challenge response (expected: #{Discourse.current_hostname}, got: #{json["domain"]})"
      log_error("request_challenge", error)
      return fail!(error:)
    end

    if Discourse.base_path.present? && json["path"] != Discourse.base_path
      error =
        "Path mismatch in challenge response (expected: #{Discourse.base_path}, got: #{json["path"]})"
      log_error("request_challenge", error)
      return fail!(error:)
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
      error = "Registration request to '#{uri}' failed: #{e.message}."
      log_error("register_with_challenge", error)
      return fail!(error:)
    end

    if response.code.to_i != 200
      error = "Registration failed: #{response.code}\nError: #{response.body}"
      log_error("register_with_challenge", error)
      return fail!(error:)
    end

    begin
      context[:data] = JSON.parse(response.body)
    rescue JSON::ParserError => e
      error = "Registration response invalid JSON: #{e.message}"
      log_error("register_with_challenge", error)
      fail!(error:)
    end
  end

  def store_credentials(data:)
    SiteSetting.discourse_id_client_id = data["client_id"]
    SiteSetting.discourse_id_client_secret = data["client_secret"]
  end

  def discourse_id_url
    @url ||= SiteSetting.discourse_id_provider_url.presence || "https://id.discourse.com"
  end

  def log_error(step, message)
    Rails.logger.error("Discourse ID registration failed at step '#{step}'. Error: #{message}")
  end
end

# frozen_string_literal: true

class DiscourseId::Register
  include Service::Base
  include DiscourseId::Concerns::ChallengeFlow

  params do
    attribute :force, :boolean, default: false
    attribute :update, :boolean, default: false
  end

  policy :not_already_registered?
  step :request_challenge
  step :store_challenge_token
  step :register_with_challenge
  step :store_credentials
  step :log_action

  private

  def not_already_registered?(params:)
    return true if params.force
    return true if params.update

    SiteSetting.discourse_id_client_id.blank? && SiteSetting.discourse_id_client_secret.blank?
  end

  def register_with_challenge(token:, params:)
    body = {
      client_name: SiteSetting.title,
      redirect_uri: "#{Discourse.base_url}/auth/discourse_id/callback",
      challenge_token: token,
      logo_uri: SiteSetting.site_logo_url.presence,
      logo_small_uri: SiteSetting.site_logo_small_url.presence,
      description: SiteSetting.site_description.presence,
    }

    if params.update
      body[:update] = true
      body[:client_id] = SiteSetting.discourse_id_client_id
      body[:client_secret] = SiteSetting.discourse_id_client_secret
    end

    response = post_json("/register", body.compact)

    return fail!(response[:error]) if response[:error]

    context[:data] = response[:data]
  end

  def store_credentials(data:, params:)
    return if params.update

    SiteSetting.discourse_id_client_id = data["client_id"]
    SiteSetting.discourse_id_client_secret = data["client_secret"]
  end

  def log_action(guardian:, params:, data:)
    return if params.update
    return if guardian.blank?

    StaffActionLogger.new(guardian.user).log_custom(
      "discourse_id_register",
      client_id: data["client_id"],
    )
  end
end

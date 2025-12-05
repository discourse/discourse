# frozen_string_literal: true

class DiscourseId::RegenerateCredentials
  include Service::Base
  include DiscourseId::Concerns::ChallengeFlow

  policy :credentials_configured?
  step :request_challenge
  step :store_challenge_token
  step :regenerate_with_challenge
  step :store_new_credentials
  step :log_action

  private

  def credentials_configured?
    SiteSetting.discourse_id_client_id.present? && SiteSetting.discourse_id_client_secret.present?
  end

  def regenerate_with_challenge(token:)
    response =
      post_json(
        "/regenerate",
        {
          client_id: SiteSetting.discourse_id_client_id,
          client_secret: SiteSetting.discourse_id_client_secret,
          challenge_token: token,
        },
      )

    return fail!(response[:error]) if response[:error]

    context[:data] = response[:data]
  end

  def store_new_credentials(data:)
    SiteSetting.discourse_id_client_secret = data["client_secret"]
  end

  def log_action(guardian:)
    StaffActionLogger.new(guardian.user).log_custom(
      "discourse_id_regenerate_credentials",
      client_id: DiscourseId.masked_client_id,
    )
  end
end

# frozen_string_literal: true

class DiscourseId::Revoke
  include Service::Base

  policy :discourse_id_properly_configured

  params do
    attribute :identifier, :string
    attribute :timestamp, :integer
    attribute :signature, :string

    validates :identifier, :timestamp, :signature, presence: true

    with_options if: -> { identifier.present? && timestamp.present? && signature.present? } do
      validate :timestamp_expired?
      validate :proper_signature?
    end

    private

    def timestamp_expired?
      time_diff = (Time.current.to_i - timestamp).abs
      return if time_diff <= 5.minutes.to_i

      errors.add(:timestamp, "is expired: #{time_diff} seconds old")
    end

    def proper_signature?
      expected_signature =
        OpenSSL::HMAC.hexdigest(
          "sha256",
          Digest::SHA256.hexdigest(SiteSetting.discourse_id_client_secret),
          "#{SiteSetting.discourse_id_client_id}:#{identifier}:#{timestamp}",
        )
      return if ActiveSupport::SecurityUtils.secure_compare(signature, expected_signature)
      errors.add(:signature, "is invalid for user id #{identifier}")
    end
  end

  model :associated_account
  step :revoke_auth_tokens

  private

  def discourse_id_properly_configured
    SiteSetting.enable_discourse_id && SiteSetting.discourse_id_client_id.present? &&
      SiteSetting.discourse_id_client_secret.present?
  end

  def fetch_associated_account(params:)
    UserAssociatedAccount.find_by(provider_name: "discourse_id", provider_uid: params.identifier)
  end

  def revoke_auth_tokens(associated_account:)
    UserAuthToken.where(user_id: associated_account.user_id).destroy_all
  end
end

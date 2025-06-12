# frozen_string_literal: true

class UserAuthToken::DestroyViaDiscourseId
  include Service::Base

  transaction do
    step :validate_timestamp
    step :validate_discourse_id
    step :validate_signature
    step :revoke_auth_tokens
  end

  private

  def validate_timestamp(params:)
    time_diff = (Time.now.to_i - params.timestamp.to_i).abs
    if time_diff > 5.minutes.to_i
      if SiteSetting.discourse_id_verbose_logging
        Rails.logger.warn(
          "Expired timestamp in discourse_id_client revoke: #{time_diff} seconds old",
        )
      end

      fail!("expired timestamp")
    end
  end

  def validate_discourse_id
    fail!("discourse id not enabled") unless SiteSetting.enable_discourse_id
    fail!("discourse_id_client_id missing") if SiteSetting.discourse_id_client_id.blank?
    fail!("discourse_id_client_secret missing") if SiteSetting.discourse_id_client_secret.blank?
  end

  def validate_signature(params:)
    hashed_secret = Digest::SHA256.hexdigest(SiteSetting.discourse_id_client_secret)

    expected_signature =
      OpenSSL::HMAC.hexdigest(
        "sha256",
        hashed_secret,
        "#{SiteSetting.discourse_id_client_id}:#{params.identifier}:#{params.timestamp}",
      )

    if !ActiveSupport::SecurityUtils.secure_compare(params.signature, expected_signature)
      if SiteSetting.discourse_id_verbose_logging
        Rails.logger.warn("Invalid signature for user id #{identifier} in discourse_id revoke")
      end

      fail!("signature invalid")
    end
  end

  def revoke_auth_tokens(params:)
    unless uaa =
             UserAssociatedAccount.find_by(
               provider_name: "discourse_id",
               provider_uid: params.identifier,
             )
      if SiteSetting.discourse_id_verbose_logging
        Rails.logger.warn("User not found with provider_uid: #{identifier}")
      end

      fail!("user not found")
    end

    UserAuthToken.where(user_id: uaa.user_id).destroy_all
  end
end

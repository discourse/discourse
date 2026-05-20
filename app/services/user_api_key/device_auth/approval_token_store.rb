# frozen_string_literal: true

class UserApiKey::DeviceAuth::ApprovalTokenStore
  SESSION_KEY = :user_api_key_device_approvals
  MAX_TOKENS = 10

  def initialize(session:, user:)
    @session = session
    @user = user
  end

  def create!(device_code)
    cleanup_expired!
    approvals.shift while approvals.length >= MAX_TOKENS

    token = SecureRandom.hex(32)
    approvals[token] = {
      "device_code" => device_code,
      "user_id" => user.id,
      "created_at" => Time.zone.now.iso8601,
    }
    persist!
    token
  end

  def device_code_for(token)
    approval = approvals[token]
    return if approval.blank?
    return if expired?(approval)
    return if approval["user_id"] != user.id

    device_code = approval["device_code"].to_s
    device_code if UserApiKey::DeviceAuth::DEVICE_CODE_REGEX.match?(device_code)
  rescue ArgumentError, TypeError
    nil
  end

  def delete!(token)
    approvals.delete(token)
    persist!
  end

  private

  attr_reader :session, :user

  def approvals
    @approvals ||= session[SESSION_KEY] ||= {}
  end

  def cleanup_expired!
    approvals.delete_if { |_, approval| expired?(approval) }
    persist!
  end

  def expired?(approval)
    created_at = Time.zone.parse(approval["created_at"])
    created_at.blank? || created_at <= UserApiKey::DeviceAuth::DEVICE_AUTH_TTL.ago
  rescue ArgumentError, TypeError
    true
  end

  def persist!
    session[SESSION_KEY] = approvals
  end
end

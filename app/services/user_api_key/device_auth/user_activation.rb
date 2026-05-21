# frozen_string_literal: true

class UserApiKey::DeviceAuth::UserActivation
  Result =
    if const_defined?(:Result, false)
      const_get(:Result)
    else
      Struct.new(:status, :grant, :device_code, :request_token, keyword_init: true)
    end

  def initialize(user:, session:)
    @user = user
    @approval_tokens = UserApiKey::DeviceAuth::ApprovalTokenStore.new(session: session, user: user)
  end

  def preview_request_token(request_token)
    grant = UserApiKey::DeviceAuth::CodeRegistry.load_by_request_token(request_token)
    return expired_result if unavailable_for_user?(grant)

    Result.new(status: :success, grant: grant, request_token: request_token)
  end

  def find_manual_code(code)
    user_code = UserApiKey::DeviceAuth::CodeRegistry.normalize_user_code(code)
    grant =
      user_code.present? ? UserApiKey::DeviceAuth::CodeRegistry.load_by_user_code(user_code) : nil
    return Result.new(status: :invalid_code) if grant.blank?
    return expired_result if unavailable_for_user?(grant)

    Result.new(status: :success, grant: grant)
  end

  def create_approval_token!(grant)
    UserApiKey::DeviceAuth::CodeRegistry.delete_user_code(grant.user_code)
    @approval_tokens.create!(grant.device_code)
  end

  def resolve_authorize_device_code(request_token:, user_code:, approval_token:)
    if request_token.present?
      resolve_request_authorize_device_code(request_token, user_code)
    else
      resolve_approval_token_device_code(approval_token)
    end
  end

  def resolve_deny_device_code(request_token:, approval_token:)
    return expired_result if request_token.present?

    resolve_approval_token_device_code(approval_token)
  end

  def delete_approval_token(token)
    @approval_tokens.delete!(token)
  end

  private

  attr_reader :user

  def resolve_request_authorize_device_code(request_token, user_code)
    grant = UserApiKey::DeviceAuth::CodeRegistry.load_by_request_token(request_token)
    return expired_result if unavailable_for_user?(grant)

    unless UserApiKey::DeviceAuth::CodeRegistry.user_code_matches_grant?(user_code, grant)
      return Result.new(status: :invalid_code, grant: grant, request_token: request_token)
    end

    return expired_result if !grant.bind_to_user!(user)

    UserApiKey::DeviceAuth::GrantStore.save!(
      grant,
      ttl: UserApiKey::DeviceAuth::GrantStore.ttl_for_update(grant.device_code),
    )

    Result.new(
      status: :success,
      grant: grant,
      device_code: grant.device_code,
      request_token: request_token,
    )
  end

  def resolve_approval_token_device_code(approval_token)
    device_code = @approval_tokens.device_code_for(approval_token)
    return expired_result if device_code.blank?

    Result.new(status: :success, device_code: device_code)
  end

  def unavailable_for_user?(grant)
    grant.blank? || !grant.pending? || grant.bound_to_another_user?(user)
  end

  def expired_result
    Result.new(status: :expired_code)
  end
end

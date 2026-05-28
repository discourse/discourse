# frozen_string_literal: true

class UserApiKey::DeviceAuth::UserActivation
  class Result
    attr_reader :status, :grant, :device_code, :request_token, :debug_reason

    def initialize(status:, grant: nil, device_code: nil, request_token: nil, debug_reason: nil)
      @status = status
      @grant = grant
      @device_code = device_code
      @request_token = request_token
      @debug_reason = debug_reason
    end
  end

  def initialize(user:, session:, request_id: nil)
    @user = user
    @request_id = request_id
    @approval_tokens = UserApiKey::DeviceAuth::ApprovalTokenStore.new(session: session, user: user)
  end

  def preview_request_token(request_token)
    if !UserApiKey::DeviceAuth::CodeRegistry.valid_request_token?(request_token)
      return(
        trace_and_return_result(
          "device_auth.activation.preview.failed",
          expired_result("invalid_request_token", request_token: request_token),
        )
      )
    end

    grant = UserApiKey::DeviceAuth::CodeRegistry.load_by_request_token(request_token)
    if (reason = unavailable_reason_for(grant))
      return(
        trace_and_return_result(
          "device_auth.activation.preview.failed",
          expired_result(reason, grant: grant, request_token: request_token),
        )
      )
    end

    trace_and_return_result(
      "device_auth.activation.preview.succeeded",
      Result.new(status: :success, grant: grant, request_token: request_token),
    )
  end

  def find_manual_code(code)
    user_code = UserApiKey::DeviceAuth::CodeRegistry.normalize_user_code(code)
    if user_code.blank?
      return(
        trace_and_return_result(
          "device_auth.activation.manual_code.failed",
          Result.new(status: :invalid_code, debug_reason: "invalid_user_code_format"),
          user_code: code,
        )
      )
    end

    grant = UserApiKey::DeviceAuth::CodeRegistry.load_by_user_code(user_code)
    if grant.blank?
      return(
        trace_and_return_result(
          "device_auth.activation.manual_code.failed",
          Result.new(status: :invalid_code, debug_reason: "user_code_not_found"),
          user_code: user_code,
        )
      )
    end

    if (reason = unavailable_reason_for(grant))
      return(
        trace_and_return_result(
          "device_auth.activation.manual_code.failed",
          expired_result(reason, grant: grant),
          user_code: user_code,
        )
      )
    end

    trace_and_return_result(
      "device_auth.activation.manual_code.succeeded",
      Result.new(status: :success, grant: grant),
      user_code: user_code,
    )
  end

  def create_approval_token!(grant)
    device_code = grant.device_code
    approval_token = nil
    failure_reason = nil

    UserApiKey::DeviceAuth::GrantStore.with_lock!(
      device_code,
      operation: "device_auth.activation.approval_token",
      request_id: request_id,
    ) do
      stored_grant = UserApiKey::DeviceAuth::GrantStore.load(device_code)
      if (failure_reason = unavailable_reason_for(stored_grant))
        next
      end

      unless stored_grant.bind_to_user!(user)
        failure_reason = "bound_to_other_user"
        next
      end

      UserApiKey::DeviceAuth::GrantStore.save!(
        stored_grant,
        ttl: UserApiKey::DeviceAuth::GrantStore.ttl_for_update(device_code),
      )
      approval_token = @approval_tokens.create!(device_code)
    end

    if approval_token.present?
      UserApiKey::DeviceAuth.trace(
        "device_auth.activation.approval_token.succeeded",
        request_id: request_id,
        user_id: user&.id,
        device_code: device_code,
        approval_token: approval_token,
      )
    else
      UserApiKey::DeviceAuth.trace(
        "device_auth.activation.approval_token.failed",
        request_id: request_id,
        reason: failure_reason || "approval_token_not_created",
        user_id: user&.id,
        device_code: device_code,
      )
    end

    approval_token
  rescue Discourse::InvalidAccess
    UserApiKey::DeviceAuth.trace(
      "device_auth.activation.approval_token.failed",
      request_id: request_id,
      reason: "lock_busy",
      user_id: user&.id,
      device_code: device_code,
    )
    nil
  end

  def resolve_authorize_device_code(request_token:, user_code:, approval_token:)
    if request_token.present?
      resolve_request_authorize_device_code(request_token, user_code)
    else
      resolve_approval_token_device_code(approval_token)
    end
  end

  def resolve_deny_device_code(request_token:, approval_token:)
    if request_token.present?
      return(
        trace_and_return_result(
          "device_auth.activation.resolve_deny.failed",
          expired_result("deny_requires_approval_token", request_token: request_token),
        )
      )
    end

    resolve_approval_token_device_code(approval_token)
  end

  def delete_approval_token(token)
    @approval_tokens.delete!(token)
    UserApiKey::DeviceAuth.trace(
      "device_auth.activation.approval_token.deleted",
      request_id: request_id,
      user_id: user&.id,
      approval_token: token,
    )
  end

  private

  attr_reader :user, :request_id

  def resolve_request_authorize_device_code(request_token, user_code)
    grant = UserApiKey::DeviceAuth::CodeRegistry.load_by_request_token(request_token)
    if (reason = unavailable_reason_for(grant))
      return(
        trace_and_return_result(
          "device_auth.activation.resolve_request.failed",
          expired_result(reason, grant: grant, request_token: request_token),
        )
      )
    end

    result = nil

    UserApiKey::DeviceAuth::GrantStore.with_lock!(
      grant.device_code,
      operation: "device_auth.activation.resolve_request",
      request_id: request_id,
    ) do
      grant = UserApiKey::DeviceAuth::CodeRegistry.load_by_request_token(request_token)

      if (reason = unavailable_reason_for(grant))
        result = expired_result(reason, grant: grant, request_token: request_token)
        next
      end

      unless UserApiKey::DeviceAuth::CodeRegistry.user_code_matches_grant?(user_code, grant)
        result =
          Result.new(
            status: :invalid_code,
            grant: grant,
            request_token: request_token,
            debug_reason: "user_code_mismatch",
          )
        next
      end

      if !grant.bind_to_user!(user)
        result = expired_result("bound_to_other_user", grant: grant, request_token: request_token)
        next
      end

      UserApiKey::DeviceAuth::GrantStore.save!(
        grant,
        ttl: UserApiKey::DeviceAuth::GrantStore.ttl_for_update(grant.device_code),
      )

      result =
        Result.new(
          status: :success,
          grant: grant,
          device_code: grant.device_code,
          request_token: request_token,
        )
    end

    if result.present?
      trace_and_return_result(
        (
          if result.status == :success
            "device_auth.activation.resolve_request.succeeded"
          else
            "device_auth.activation.resolve_request.failed"
          end
        ),
        result,
        user_code: user_code,
      )
    else
      trace_and_return_result(
        "device_auth.activation.resolve_request.failed",
        expired_result("empty_lock_result", grant: grant, request_token: request_token),
        user_code: user_code,
      )
    end
  rescue Discourse::InvalidAccess
    trace_and_return_result(
      "device_auth.activation.resolve_request.failed",
      expired_result("lock_busy", grant: grant, request_token: request_token),
      user_code: user_code,
    )
  end

  def resolve_approval_token_device_code(approval_token)
    device_code = @approval_tokens.device_code_for(approval_token)
    if device_code.blank?
      return(
        trace_and_return_result(
          "device_auth.activation.resolve_approval_token.failed",
          expired_result("approval_token_invalid"),
          approval_token: approval_token,
        )
      )
    end

    trace_and_return_result(
      "device_auth.activation.resolve_approval_token.succeeded",
      Result.new(status: :success, device_code: device_code),
      approval_token: approval_token,
    )
  end

  def unavailable_reason_for(grant)
    return "grant_missing" if grant.blank?
    return "grant_not_pending" if !grant.pending?
    return "user_missing" if user.blank?

    "bound_to_other_user" if grant.bound_to_another_user?(user)
  end

  def expired_result(debug_reason, grant: nil, request_token: nil)
    Result.new(
      status: :expired_code,
      grant: grant,
      request_token: request_token,
      debug_reason: debug_reason,
    )
  end

  def trace_and_return_result(event, result, **payload)
    UserApiKey::DeviceAuth.trace(
      event,
      **{
        request_id: request_id,
        reason: result.debug_reason,
        status: result.status,
        user_id: user&.id,
        client_id: result.grant&.client_id,
        device_code: result.device_code || result.grant&.device_code,
        request_token: result.request_token,
      }.merge(payload),
    )
    result
  end
end

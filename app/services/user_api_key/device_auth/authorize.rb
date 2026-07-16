# frozen_string_literal: true

class UserApiKey::DeviceAuth::Authorize
  include Service::Base

  params do
    attribute :device_code, :string
    attribute :user_id, :integer

    validates :device_code, presence: true
    validates :user_id, presence: true
  end

  options { attribute :request_id, :string }

  model :user

  try Discourse::InvalidParameters, Discourse::InvalidAccess do
    step :authorize_grant
  end

  private

  def fetch_user(params:)
    User.find_by(id: params.user_id)
  end

  def authorize_grant(params:, user:, options:)
    UserApiKey::DeviceAuth::GrantStore.with_lock!(
      params.device_code,
      operation: "device_auth.authorize",
      request_id: options.request_id,
    ) do
      grant = UserApiKey::DeviceAuth::GrantStore.load(params.device_code)

      if grant.blank?
        fail_authorize_grant!(
          "grant_missing",
          params: params,
          user: user,
          request_id: options.request_id,
        )
      end

      if !grant.pending?
        fail_authorize_grant!(
          "grant_not_pending",
          params: params,
          user: user,
          grant: grant,
          request_id: options.request_id,
        )
      end

      if grant.bound_to_another_user?(user)
        fail_authorize_grant!(
          "bound_to_other_user",
          params: params,
          user: user,
          grant: grant,
          request_id: options.request_id,
        )
      end

      key = UserApiKey::DeviceAuth::KeyCreator.create!(grant, user)
      grant.authorize!(
        payload: UserApiKey::DeviceAuth::PayloadBuilder.encrypted_payload!(grant, key),
      )

      UserApiKey::DeviceAuth::GrantStore.save!(
        grant,
        ttl: UserApiKey::DeviceAuth::GrantStore.authorized_payload_ttl(params.device_code),
      )
      UserApiKey::DeviceAuth::CodeRegistry.delete_indexes_for(grant)
      context[:grant] = grant
      UserApiKey::DeviceAuth.trace(
        "device_auth.authorize.succeeded",
        request_id: options.request_id,
        client_id: grant.client_id,
        device_code: grant.device_code,
        user_id: user.id,
      )
    end
  rescue Discourse::InvalidParameters, Discourse::InvalidAccess => exception
    UserApiKey::DeviceAuth.trace(
      "device_auth.authorize.failed",
      request_id: options.request_id,
      reason: exception.class.name,
      exception: exception,
      device_code: params.device_code,
      user_id: user.id,
    )
    raise
  end

  def fail_authorize_grant!(reason, params:, user:, request_id:, grant: nil)
    UserApiKey::DeviceAuth.trace(
      "device_auth.authorize.failed",
      request_id: request_id,
      reason: reason,
      status: grant&.status,
      client_id: grant&.client_id,
      device_code: params.device_code,
      user_id: user.id,
    )
    context["result.step.authorize_grant"].fail(error: reason)
    context.fail!
  end
end

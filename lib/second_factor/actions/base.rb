# frozen_string_literal: true

module SecondFactor::Actions
  # Base contract for actions guarded by SecondFactor::AuthManager via `run_second_factor!`.
  # Subclasses must implement:
  # - `no_second_factors_enabled!(params)`: invoked when the target user has no allowed 2FA method.
  # - `second_factor_auth_required!(params)`: returns `{ callback_params:, redirect_url:, callback_method:, callback_path:, description: }`.
  # - `second_factor_auth_completed!(callback_params)`: performs the action after challenge verification.
  # Optional hooks:
  # - `challenge_scope`: primitive value binding the challenge to a specific resource (default `nil`).
  # - `skip_second_factor_auth?(params)` / `second_factor_auth_skipped!(params)`.
  class Base
    include Rails.application.routes.url_helpers
    attr_reader :current_user, :guardian, :request

    def initialize(guardian, request, target_user:, opts: nil)
      @guardian = guardian
      @current_user = guardian.user
      @target_user = target_user
      @request = request
      @opts = ActiveSupport::HashWithIndifferentAccess.new(opts)
    end

    def challenge_scope
      nil
    end

    def skip_second_factor_auth?(params)
      false
    end

    def second_factor_auth_skipped!(params)
      raise NotImplementedError.new
    end

    def no_second_factors_enabled!(params)
      raise NotImplementedError.new
    end

    def second_factor_auth_required!(params)
      raise NotImplementedError.new
    end

    def second_factor_auth_completed!(callback_params)
      raise NotImplementedError.new
    end
  end
end

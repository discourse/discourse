# frozen_string_literal: true

module SecondFactor::Actions
  class Base
    include Rails.application.routes.url_helpers
    attr_reader :current_user, :guardian, :request

    def initialize(guardian, request, target_user:, opts: nil)
      @guardian = guardian
      @current_user = guardian.user
      @target_user = target_user
      @request = request
      @opts = HashWithIndifferentAccess.new(opts)
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

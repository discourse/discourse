# frozen_string_literal: true

module SecondFactor::Actions
  class Base
    include Rails.application.routes.url_helpers
    attr_reader :current_user, :guardian

    def initialize(current_user, guardian)
      @current_user = current_user
      @guardian = guardian
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

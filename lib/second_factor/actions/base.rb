# frozen_string_literal: true

module SecondFactor::Actions
  class Base
    def initialize(params, current_user, guardian)
      raise NotImplementedError.new
    end

    def no_second_factors_enabled!
      raise NotImplementedError.new
    end

    def second_factor_auth_required!
      raise NotImplementedError.new
    end

    def second_factor_auth_successful!
      raise NotImplementedError.new
    end
  end
end

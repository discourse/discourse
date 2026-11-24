# frozen_string_literal: true

module SecondFactor::Actions
  class Login < Base
    def challenge_scope
      @opts.fetch(:flow)
    end

    def no_second_factors_enabled!(_params)
    end

    def second_factor_auth_required!(_params)
      {
        callback_method: "POST",
        callback_path: @opts.fetch(:callback_path),
        callback_params: @opts.fetch(:payload),
      }
    end

    def second_factor_auth_completed!(callback_params)
      callback_params.with_indifferent_access
    end
  end
end

# frozen_string_literal: true

module SecondFactor::Actions
  class ConfirmEmail < Base
    def challenge_scope
      @opts.fetch(:change_request_id)
    end

    def no_second_factors_enabled!(params)
      # handled in controller
    end

    def second_factor_auth_required!(_params)
      {
        redirect_url:
          (
            if @current_user
              "#{Discourse.base_path}/my/preferences/account"
            else
              "#{Discourse.base_path}/login"
            end
          ),
      }
    end

    def second_factor_auth_completed!(_callback_params)
      # handled in controller
    end
  end
end

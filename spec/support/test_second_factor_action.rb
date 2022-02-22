# frozen_string_literal: true

class TestSecondFactorAction < SecondFactor::Actions::Base
  def no_second_factors_enabled!(params)
  end

  def second_factor_auth_required!(params)
    {
      redirect_path: params[:redirect_path],
      callback_params: {
        saved_param_1: params[:saved_param_1],
        saved_param_2: params[:saved_param_2]
      }
    }
  end

  def second_factor_auth_completed!(callback_params)
  end
end

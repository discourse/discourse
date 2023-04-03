# frozen_string_literal: true

class TestSecondFactorAction < SecondFactor::Actions::Base
  def no_second_factors_enabled!(params)
  end

  def second_factor_auth_required!(params)
    {
      redirect_url: params[:redirect_url],
      callback_params: {
        saved_param_1: params[:saved_param_1],
        saved_param_2: params[:saved_param_2],
      },
      description: "this is description for test action",
    }
  end

  def second_factor_auth_completed!(callback_params)
  end
end

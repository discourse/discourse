# frozen_string_literal: true

module SessionControllerExtension
  def self.included(base)
    base.skip_before_action :check_xhr, only: %i[test_second_factor_restricted_route]
  end

  def test_second_factor_restricted_route
    result =
      run_second_factor!(TestSecondFactorAction) do |manager|
        manager.allow_backup_codes! if params[:allow_backup_codes]
      end
    if result.no_second_factors_enabled?
      render json: { result: "no_second_factors_enabled" }
    else
      render json: { result: "second_factor_auth_completed" }
    end
  end
end

SessionController.class_eval { include SessionControllerExtension }

# frozen_string_literal: true

class SecondFactor::AuthManagerResult
  STATUSES = {
    no_second_factor: 1,
    second_factor_auth_successful: 3,
  }.freeze

  def no_second_factors_enabled?
    @status == STATUSES[:no_second_factor]
  end

  def second_factor_auth_successful?
    @status == STATUSES[:second_factor_auth_successful]
  end

  def set_status(status)
    if !STATUSES.key?(status)
      raise ArgumentError.new("invalid second factor status key #{status.inspect}")
    end
    @status = STATUSES[status]
  end
end

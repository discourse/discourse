# frozen_string_literal: true

class SecondFactor::AuthManagerResult
  STATUSES = {
    no_second_factor: 1,
    second_factor_auth_completed: 2,
    second_factor_auth_skipped: 3,
  }.freeze

  private_constant :STATUSES
  attr_reader :data

  def initialize(status, data)
    if !STATUSES.key?(status)
      raise ArgumentError.new(
              "#{status.inspect} is not a valid status. Allowed statuses: #{STATUSES.inspect}",
            )
    end
    @status_id = STATUSES[status]
    @data = data
  end

  def no_second_factors_enabled?
    @status_id == STATUSES[:no_second_factor]
  end

  def second_factor_auth_completed?
    @status_id == STATUSES[:second_factor_auth_completed]
  end

  def second_factor_auth_skipped?
    @status_id == STATUSES[:second_factor_auth_skipped]
  end
end

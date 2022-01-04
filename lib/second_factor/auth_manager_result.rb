# frozen_string_literal: true

class SecondFactor::AuthManagerResult
  class StrictEnum
    def initialize(hash)
      @hash = hash
    end

    def [](key)
      if !@hash.key?(key)
        raise ArgumentError.new("key #{key.inspect} is not in enum #{@hash.inspect}")
      end
      @hash[key]
    end
  end

  STATUSES = StrictEnum.new({
    no_second_factor: 1,
    second_factor_auth_completed: 2,
  }.freeze)

  private_constant :StrictEnum, :STATUSES

  def initialize(status)
    @status_id = STATUSES[status]
  end

  def no_second_factors_enabled?
    @status_id == STATUSES[:no_second_factor]
  end

  def second_factor_auth_completed?
    @status_id == STATUSES[:second_factor_auth_completed]
  end
end

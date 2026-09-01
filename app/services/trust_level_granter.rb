# frozen_string_literal: true

class TrustLevelGranter
  class << self
    def grant(trust_level, user)
      TrustLevelGranter.new(trust_level, user).grant
    end
  end
  def initialize(trust_level, user)
    @trust_level, @user = trust_level, user
  end

  def grant
    if @user.trust_level < @trust_level
      @user.change_trust_level!(@trust_level)
      @user.save!
    end
  end
end

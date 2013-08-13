require_dependency 'promotion'

class BoostTrustLevel

  def initialize(args)
    @user = args[:user]
    @level = args[:level].to_i
    @promotion = Promotion.new(@user)
    @trust_levels = TrustLevel.levels
    @logger = args[:logger]
  end

  def save!
    previous_level = @user.trust_level
    success = if @level < @user.trust_level
                demote!
              else
                @user.update_attributes!(trust_level: @level)
              end
    @logger.log_trust_level_change(@user, previous_level, @level)
    success
  end

  protected

  def demote!
    current_trust_level = @user.trust_level
    @user.update_attributes!(trust_level: @level)
    if @promotion.review
      @user.update_attributes!(trust_level: current_trust_level)
      raise Discourse::InvalidAccess.new, I18n.t('trust_levels.change_failed_explanation',
                                                 user_name: @user.name,
                                                 new_trust_level: trust_level_lookup(@level),
                                                 current_trust_level: trust_level_lookup(current_trust_level))
    else
      true
    end
  end

  def trust_level_lookup(level)
    @trust_levels.key(level).id2name
  end

end

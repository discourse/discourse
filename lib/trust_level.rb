# frozen_string_literal: true

class InvalidTrustLevel < StandardError
end

class TrustLevel
  def self.[](level)
    raise InvalidTrustLevel if !valid?(level)

    level
  end

  def self.levels
    @levels ||= Enum.new(:newuser, :basic, :member, :regular, :leader, start: 0)
  end

  def self.valid?(level)
    valid_range === level
  end

  def self.valid_range
    (0..4)
  end

  def self.compare(current_level, level)
    (current_level || 0) >= level
  end

  def self.name(level)
    I18n.t("js.trust_levels.names.#{levels[level]}")
  end

  def self.calculate(user, use_previous_trust_level: false)
    # First, use the manual locked level
    return user.manual_locked_trust_level if user.manual_locked_trust_level.present?

    # Then consider the group locked level (or the previous trust level)
    granted_trust_level = user.group_granted_trust_level || 0
    previous_trust_level = use_previous_trust_level ? find_previous_trust_level(user) : 0
    invitee_trust_level =
      user.invited_user&.redeemed_at ? SiteSetting.default_invitee_trust_level : 0

    [
      granted_trust_level,
      previous_trust_level,
      invitee_trust_level,
      SiteSetting.default_trust_level,
    ].max
  end

  private

  def self.find_previous_trust_level(user)
    UserHistory
      .where(action: UserHistory.actions[:change_trust_level])
      .where(target_user_id: user.id)
      .order(created_at: :desc)
      .pick(:new_value)
      .to_i
  end
end

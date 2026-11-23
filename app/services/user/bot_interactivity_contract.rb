# frozen_string_literal: true

class User::BotInteractivityContract < Service::ContractBase
  TRUE_VALUES = [true, 1, "1", "true", "on"].freeze
  FALSE_VALUES = [false, 0, "0", "false", "off"].freeze
  private_constant :TRUE_VALUES, :FALSE_VALUES

  attribute :interactive_bot
  validate do
    if TRUE_VALUES.exclude?(interactive_bot) && FALSE_VALUES.exclude?(interactive_bot)
      errors.add(:interactive_bot, :inclusion)
    end
  end

  def interactive_bot_enabled?
    TRUE_VALUES.include?(interactive_bot)
  end
end

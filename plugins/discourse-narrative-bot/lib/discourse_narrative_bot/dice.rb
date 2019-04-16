module DiscourseNarrativeBot
  class Dice
    def self.roll(dice_description)
      begin
        dice = GamesDice.create(dice_description)
        dice.roll
        I18n.t('discourse_narrative_bot.dice.result', result: dice.result, detailed_result: dice.explain_result)
      rescue Parslet::ParseFailed
        I18n.t('discourse_narrative_bot.dice.invalid')
      end
    end
  end
end

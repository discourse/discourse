module DiscourseNarrativeBot
  class Dice
    MAXIMUM_NUM_OF_DICE = 20
    MAXIMUM_RANGE_OF_DICE = 120

    def self.roll(num_of_dice, range_of_dice)
      if num_of_dice == 0 || range_of_dice == 0
        return I18n.t('discourse_narrative_bot.dice.invalid')
      end

      output = ''

      if num_of_dice > MAXIMUM_NUM_OF_DICE
        output << I18n.t('discourse_narrative_bot.dice.not_enough_dice',
          num_of_dice: MAXIMUM_NUM_OF_DICE
        )
        output << "\n\n"
        num_of_dice = MAXIMUM_NUM_OF_DICE
      end

      if range_of_dice > MAXIMUM_RANGE_OF_DICE
        output << I18n.t('discourse_narrative_bot.dice.out_of_range')
        output << "\n\n"
        range_of_dice = MAXIMUM_RANGE_OF_DICE
      end

      output << I18n.t('discourse_narrative_bot.dice.results',
        results: num_of_dice.times.map { rand(1..range_of_dice) }.join(", ")
      )
    end
  end
end

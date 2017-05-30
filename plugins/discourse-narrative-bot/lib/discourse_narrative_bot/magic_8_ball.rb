module DiscourseNarrativeBot
  class Magic8Ball
    def self.generate_answer
      I18n.t("discourse_narrative_bot.magic_8_ball.result", result: I18n.t(
        "discourse_narrative_bot.magic_8_ball.answers.#{rand(1..20)}"
      ))
    end
  end
end

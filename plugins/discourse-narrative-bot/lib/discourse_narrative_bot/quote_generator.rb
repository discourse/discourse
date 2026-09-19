# frozen_string_literal: true

module DiscourseNarrativeBot
  class QuoteGenerator
    def self.format_quote(quote, author)
      I18n.t("discourse_narrative_bot.quote.results", quote:, author:)
    end

    def self.generate(user)
      I18n.with_locale(user.effective_locale) do
        quote = I18n.t("discourse_narrative_bot.quote").values.select { |v| v.is_a?(Hash) }.sample
        format_quote(quote[:quote], quote[:author])
      end
    end
  end
end

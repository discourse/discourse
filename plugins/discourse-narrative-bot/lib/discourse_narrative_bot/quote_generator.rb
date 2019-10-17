# frozen_string_literal: true

require 'excon'

module DiscourseNarrativeBot
  class QuoteGenerator
    API_ENDPOINT = 'http://api.forismatic.com/api/1.0/'.freeze

    def self.format_quote(quote, author)
      I18n.t('discourse_narrative_bot.quote.results', quote: quote, author: author)
    end

    def self.generate(user)
      quote, author =
        if !user.effective_locale.start_with?('en')
          translation_key = "discourse_narrative_bot.quote.#{rand(1..10)}"

          [
            I18n.t("#{translation_key}.quote"),
            I18n.t("#{translation_key}.author")
          ]
        else
          connection = Excon.new("#{API_ENDPOINT}?lang=en&format=json&method=getQuote")
          response = connection.request(expects: [200, 201], method: :Get)

          response_body = JSON.parse(response.body)
          [response_body["quoteText"].strip, response_body["quoteAuthor"].strip]
        end

      format_quote(quote, author)
    end
  end
end

require 'excon'

module DiscourseNarrativeBot
  class QuoteGenerator
    API_ENDPOINT = 'http://api.forismatic.com/api/1.0/'.freeze

    def self.generate(user)
      quote, author =
        if user.effective_locale != 'en'
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

      I18n.t('discourse_narrative_bot.quote.results', quote: quote, author: author)
    end
  end
end

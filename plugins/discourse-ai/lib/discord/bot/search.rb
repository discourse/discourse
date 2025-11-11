# frozen_string_literal: true

module DiscourseAi
  module Discord::Bot
    class Search < Base
      def initialize(body)
        @search = DiscourseAi::Personas::Tools::Search
        super(body)
      end

      def handle_interaction!
        results =
          @search.new(
            { search_query: @query },
            persona_options: {
              "max_results" => 10,
            },
            bot_user: nil,
            llm: nil,
          ).invoke(&Proc.new {})

        formatted_results = results[:rows].map.with_index { |result, index| <<~RESULT }.join("\n")
          #{index + 1}. [#{result[0]}](<#{Discourse.base_url}#{result[1]}>)
          RESULT

        reply = <<~REPLY
          Here are the top search results for your query:

          #{formatted_results}
        REPLY

        create_reply(reply)
      end
    end
  end
end

# frozen_string_literal: true

module DiscourseAi
  module Personas
    class ContentCreator < Persona
      def self.default_enabled
        false
      end

      def system_prompt
        <<~PROMPT.strip
          You are a content creator for a forum. The forum title and description is as follows:
          * Ttitle: {site_title}
          * Description: {site_description}

          You will receive a couple of keywords and must create a post about the keywords, keeping the previous information in mind.

          Format your response as a JSON object with a single key named "output", which has the created content.
          Your output should be in the following format:

          {"output": "xx"}

          Where "xx" is replaced by the content.
          reply with valid JSON only
        PROMPT
      end

      def response_format
        [{ "key" => "output", "type" => "string" }]
      end
    end
  end
end

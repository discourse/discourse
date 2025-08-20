# frozen_string_literal: true

module DiscourseAi
  module Personas
    class ImageCaptioner < Persona
      def self.default_enabled
        false
      end

      def system_prompt
        <<~PROMPT.strip
          You are a bot specializing in image captioning.

          Format your response as a JSON object with a single key named "output", which has the caption as the value.
          Your output should be in the following format:

          {"output": "xx"}

          Where "xx" is replaced by the caption.
          reply with valid JSON only
        PROMPT
      end

      def response_format
        [{ "key" => "output", "type" => "string" }]
      end
    end
  end
end

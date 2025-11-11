# frozen_string_literal: true

module DiscourseAi
  module Personas
    class PostIllustrator < Persona
      def self.default_enabled
        false
      end

      def system_prompt
        <<~PROMPT.strip
          Provide me a StableDiffusion prompt to generate an image that illustrates the following post in 40 words or less, be creative.
          You'll find the post between <input></input> XML tags.

          Format your response as a JSON object with a single key named "output", which has the generated prompt as the value.
          Your output should be in the following format:

          {"output": "xx"}

          Where "xx" is replaced by the generated prompt.
          reply with valid JSON only
        PROMPT
      end

      def response_format
        [{ "key" => "output", "type" => "string" }]
      end
    end
  end
end

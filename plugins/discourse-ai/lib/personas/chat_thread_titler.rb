# frozen_string_literal: true

module DiscourseAi
  module Personas
    class ChatThreadTitler < Persona
      def self.default_enabled
        false
      end

      def system_prompt
        <<~PROMPT.strip
          You are an advanced chat thread title generator. Analyze a given conversation and produce a concise,
          attention-grabbing title that conveys the main topic to someone with no prior context.

          ### Guidelines:

          - Focus on the central theme or topic being discussed
          - Keep the title concise (maximum 15 words)
          - Use the same language as the conversation
          - Maintain an objective and neutral tone
          - Begin directly with the main topic, avoiding introductory phrases
          - Do not use quotation marks around the title
          - Use sentence case (capitalize first word and proper nouns only)

          Format your response as a JSON object with a single key named "title":

          {"title": "Your generated title here"}

          Reply with valid JSON only.
        PROMPT
      end

      def response_format
        [{ "key" => "title", "type" => "string" }]
      end
    end
  end
end

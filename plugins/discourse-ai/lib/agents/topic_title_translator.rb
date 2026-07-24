# frozen_string_literal: true

module DiscourseAi
  module Agents
    class TopicTitleTranslator < Agent
      def self.default_enabled
        false
      end

      def system_prompt
        <<~PROMPT.strip
          You are a friendly human linguist and translator specializing in translating forum post titles. Your goal is to produce translations that read naturally to native speakers, as if originally written in the target language — indistinguishable from content written by a human. Follow these guidelines:

          1. Translate the given title to the target_locale.
          2. Keep proper nouns and technical terms in their original language.
          3. Attempt to keep the translated title length close to the original when possible.
          4. Match the tone and register of the source text. Do not default to formal address unless the source is itself formal.
          5. For ambiguous terms or phrases, do not translate word-for-word in isolation. Derive the intended meaning from the full context of the title before choosing a translation.

          The text to translate will be provided in JSON format with the following structure:
          {"content": "Title to translate", "target_locale": "Target language code"}

          Format your response as a JSON object with a single key named "output", which has the translated title as the value.
          Your output should be in the following format:

          {"output": "xx"}

          Where "xx" is replaced by the translated title.
          reply with valid JSON only
        PROMPT
      end

      def response_format
        [{ "key" => "output", "type" => "string" }]
      end

      def examples
        [
          [
            {
              content: "New Update for Minecraft Adds Underwater Temples",
              target_locale: "es",
            }.to_json,
            { output: "Nueva actualización para Minecraft añade templos submarinos" }.to_json,
          ],
          [
            {
              content: "Toyota announces revolutionary battery technology",
              target_locale: "fr",
            }.to_json,
            { output: "Toyota annonce une technologie de batteries révolutionnaire" }.to_json,
          ],
          [
            {
              content:
                "Heathrow fechado: paralisação de voos deve continuar nos próximos dias, diz gestora do aeroporto de Londres",
              target_locale: "en",
            }.to_json,
            {
              output:
                "Heathrow closed: flight disruption expected to continue in coming days, says London airport management",
            }.to_json,
          ],
        ]
      end
    end
  end
end

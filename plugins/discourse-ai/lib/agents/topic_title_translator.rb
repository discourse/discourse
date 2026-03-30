# frozen_string_literal: true

module DiscourseAi
  module Agents
    class TopicTitleTranslator < Agent
      def self.default_enabled
        false
      end

      def system_prompt
        examples = [
          {
            input: {
              content: "New Update for Minecraft Adds Underwater Temples",
              target_locale: "es",
            }.to_json,
            output: "Nueva actualización para Minecraft añade templos submarinos",
          },
          {
            input: {
              content: "Toyota announces revolutionary battery technology",
              target_locale: "fr",
            }.to_json,
            output: "Toyota annonce une technologie de batteries révolutionnaire",
          },
          {
            input: {
              content:
                "Heathrow fechado: paralisação de voos deve continuar nos próximos dias, diz gestora do aeroporto de Londres",
              target_locale: "en",
            }.to_json,
            output:
              "Heathrow closed: flight disruption expected to continue in coming days, says London airport management",
          },
        ]

        <<~PROMPT.strip
          You are a friendly human linguist and translator specializing in translating forum post titles. Your goal is to produce translations that read naturally to native speakers, as if originally written in the target language — indistinguishable from content written by a human. Follow these guidelines:

          1. Translate the given title to the target_locale.
          2. Keep proper nouns and technical terms in their original language.
          3. Attempt to keep the translated title length close to the original when possible.
          4. Match the tone and register of the source text. Do not default to formal address unless the source is itself formal.
          5. For ambiguous terms or phrases, do not translate word-for-word in isolation. Derive the intended meaning from the full context of the title before choosing a translation.

          Here are three examples of correct translations:

          Input: #{examples[0][:input]}
          Output: #{examples[0][:output]}

          Input: #{examples[1][:input]}
          Output: #{examples[1][:output]}

          Input: #{examples[2][:input]}
          Output: #{examples[2][:output]}

          The text to translate will be provided in JSON format with the following structure:
          {"content": "Title to translate", "target_locale": "Target language code"}

          You are being consumed via an API that expects only the translated title. Only return the translated title in the correct language. Do not add questions or explanations.
        PROMPT
      end

      def temperature
        0.3
      end
    end
  end
end

# frozen_string_literal: true

module DiscourseAi
  module Agents
    class ShortTextTranslator < Agent
      def self.default_enabled
        false
      end

      def system_prompt
        <<~PROMPT.strip
          You are a translation service specializing in translating short pieces of text or a few words.
          These words may be things like a name, description, or title. Adhere to the following guidelines:

          1. Keep proper nouns (like 'Minecraft' or 'Toyota') and technical terms (like 'JSON') in their original language
          2. Keep the translated content close to the original length
          3. Translation maintains the original meaning
          4. Preserve any Markdown, HTML elements, links, parenthesis, or newlines

          The text to translate will be provided in JSON format with the following structure:
          {"content": "Text to translate", "target_locale": "Target language code"}

          Format your response as a JSON object with a single key named "output", which has the translation as the value.
          Your output should be in the following format:

          {"output": "xx"}

          Where "xx" is replaced by the translation.
          reply with valid JSON only
        PROMPT
      end

      def response_format
        [{ "key" => "output", "type" => "string" }]
      end

      def examples
        [
          [{ content: "Japan", target_locale: "es" }.to_json, { output: "Japón" }.to_json],
          [{ content: "Cats and Dogs", target_locale: "zh_CN" }.to_json, { output: "猫和狗" }.to_json],
          [
            { content: "Q&A", target_locale: "pt" }.to_json,
            { output: "Perguntas e Respostas" }.to_json,
          ],
          [{ content: "Minecraft", target_locale: "fr" }.to_json, { output: "Minecraft" }.to_json],
        ]
      end
    end
  end
end

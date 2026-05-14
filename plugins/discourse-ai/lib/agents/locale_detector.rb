# frozen_string_literal: true

module DiscourseAi
  module Agents
    class LocaleDetector < Agent
      def self.default_enabled
        false
      end

      STATIC_LANGUAGE_CODES = %w[en es fr de it pt-BR ru zh-CN ja ko].freeze

      def system_prompt
        <<~PROMPT.strip
          You will be given a piece of text, and your task is to detect the locale (language) of the text and return it in a specific JSON format.

          To complete this task, follow these steps:

          1. Carefully read and analyze the provided text.
          2. Determine the language of the text based on its characteristics, such as vocabulary, grammar, and sentence structure.
          3. Do not use links or programming code in the text to detect the locale
          4. Identify the appropriate language code for the detected language.

          Here is a list of common language codes for reference:
          - English: en
          - Spanish: es
          - French: fr
          - German: de
          - Italian: it
          - Brazilian Portuguese: pt-BR
          - Russian: ru
          - Simplified Chinese: zh-CN
          - Japanese: ja
          - Korean: ko
          #{configured_locale_lines}
          If the language is not in this list, use the appropriate IETF language tag code.

          5. Avoid using `und` and prefer `en` over `en-US` or `en-GB` unless the text specifically indicates a regional variant.

          Important: Base your analysis solely on the provided text. Do not use any external information or make assumptions about the text's origin or context beyond what is explicitly provided.

          Your response must be a language code, and nothing else. Do not wrap your response in quotes or any other characters.
        PROMPT
      end

      def examples
        [
          ["Can you tell me what '私の世界で一番好きな食べ物はちらし丼です' means?", "en"],
          [
            "[quote]\nNon smettere mai di credere nella bellezza dei tuoi sogni. Anche quando tutto sembra perduto, c'è sempre una luce che aspetta di essere trovata.\nOgni passo, anche il più piccolo, ti avvicina a ciò che desideri. La forza che cerchi è già dentro di te.\n[/quote]\n¿Cuál es el mensaje principal de esta cita?",
            "es",
          ],
        ]
      end

      def temperature
        0
      end

      private

      def configured_locale_lines
        settings =
          SiteSetting.content_localization_supported_locales.to_s.split("|").reject(&:blank?)
        return "" if settings.empty?

        configured =
          settings.filter_map do |locale|
            lang =
              LocaleSiteSetting.language_names[locale] ||
                LocaleSiteSetting.language_names[locale.split("_").first]
            next if lang.nil? || lang["name"].blank?

            hyphenated = locale.tr("_", "-")
            next if STATIC_LANGUAGE_CODES.include?(hyphenated)

            "- #{lang["name"]}: #{hyphenated}"
          end

        configured.empty? ? "" : "#{configured.join("\n")}\n"
      end
    end
  end
end

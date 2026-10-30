# frozen_string_literal: true

module DiscourseAi
  module Translation
    # Asks a decision model which language a text is written in. Localization works on base
    # languages, so each choice covers every regional variant of its language.
    class DecisionLocaleDetector
      FEATURE_NAME = "locale_detection"
      QUESTION_NAME = "language"
      # below this the detector agent decides instead
      CONFIDENT_PROBABILITY = 0.9
      OTHER_CHOICE = "other: any language not listed above"
      INSTRUCTIONS =
        "Which language did the author write this text in? Judge by the author's own words and " \
          "ignore quoted passages, error messages, code, URLs, file paths, usernames and emoji. " \
          "Each choice covers every regional variant of its language. Choose other when the " \
          "language is not listed."

      # base language => [name, the variants its choice covers]
      COMMON_LANGUAGES = {
        "en" => ["English", "American, British, Australian and any other English variant"],
        "es" => ["Spanish", "Castilian, Latin American and any other Spanish variant"],
        "pt" => [
          "Portuguese",
          "European Portuguese, Brazilian Portuguese and any other Portuguese variant",
        ],
        "fr" => [
          "French",
          "French from France, Canada, Belgium, Switzerland, Africa and any other French variant",
        ],
        "de" => [
          "German",
          "German from Germany, Austria, Switzerland and any other German variant",
        ],
        "it" => ["Italian", "Italian from Italy, Switzerland and any other Italian variant"],
        "nl" => [
          "Dutch",
          "Dutch from the Netherlands, Flemish from Belgium and any other Dutch variant",
        ],
        "ru" => ["Russian", "Russian in any country or variant"],
        "uk" => ["Ukrainian", "Ukrainian in any variant"],
        "pl" => ["Polish", "Polish in any variant"],
        "tr" => ["Turkish", "Turkish from Turkey, Cyprus and any other Turkish variant"],
        "ar" => ["Arabic", "Modern Standard Arabic and any regional Arabic dialect"],
        "he" => ["Hebrew", "Modern Hebrew in any variant"],
        "fa" => [
          "Persian",
          "Farsi from Iran, Dari from Afghanistan, Tajik Persian and any other Persian variant",
        ],
        "hi" => ["Hindi", "Hindi in Devanagari script and any other Hindi variant"],
        "ja" => ["Japanese", "Japanese in any script or variant"],
        "ko" => ["Korean", "Korean from South or North Korea and any other Korean variant"],
        "zh" => [
          "Chinese",
          "Simplified, Traditional, Mandarin, Cantonese and any other Chinese variant",
        ],
        "vi" => ["Vietnamese", "Vietnamese in any variant"],
        "th" => ["Thai", "Thai in any variant"],
        "id" => ["Indonesian", "Bahasa Indonesia in any variant"],
        "sv" => ["Swedish", "Swedish from Sweden, Finland and any other Swedish variant"],
        "da" => ["Danish", "Danish in any variant"],
        "nb" => ["Norwegian", "Bokmål, Nynorsk and any other Norwegian variant"],
        "fi" => ["Finnish", "Finnish in any variant"],
        "cs" => ["Czech", "Czech in any variant"],
        "el" => ["Greek", "Modern Greek from Greece, Cyprus and any other Greek variant"],
        "ro" => ["Romanian", "Romanian from Romania, Moldova and any other Romanian variant"],
        "hu" => ["Hungarian", "Hungarian in any variant"],
      }.freeze

      def self.decision_model
        id = SiteSetting.ai_translation_locale_detector_decision_model
        DecisionModel.find_by(id:) if id.present?
      end

      def initialize(decision_model)
        @decision_model = decision_model
      end

      # @return [String, nil] the detected locale; nil when the language is not listed or the
      #   model is unsure, so the detector agent should decide
      # @raise [DiscourseAi::Decisions::Error]
      def detect(text)
        bases_by_choice = choices
        result =
          @decision_model.decide(
            text[0, LanguageDetector::DETECTION_CHAR_LIMIT],
            questions: [
              {
                name: QUESTION_NAME,
                type: "choice",
                instructions: INSTRUCTIONS,
                choices: [*bases_by_choice.keys, OTHER_CHOICE],
              },
            ],
            feature_name: FEATURE_NAME,
            user: Discourse.system_user,
          )

        answer = result[QUESTION_NAME]
        return if answer.refusal?
        return if answer.probabilities.fetch(answer.choice) < CONFIDENT_PROBABILITY

        base = bases_by_choice[answer.choice]
        locale_for(base) if base
      end

      private

      def site_locales
        [
          SiteSetting.default_locale,
          *SiteSetting.content_localization_supported_locales.split("|"),
        ].compact_blank.uniq
      end

      # Sites may use languages beyond the common ones, and those must be detectable too.
      def choices
        languages = COMMON_LANGUAGES.dup
        site_locales.each do |locale|
          base = locale.split("_").first
          next if languages.key?(base)

          names = LocaleSiteSetting.language_names
          name = (names[base] || names[locale])&.dig("name")
          languages[base] = [name, "#{name} in any variant"] if name.present?
        end

        languages.to_h { |base, (name, variants)| ["#{name} (#{base}): #{variants}", base] }
      end

      # Prefers the variant the site is configured with, e.g. pt_BR over pt.
      def locale_for(base)
        site_locales.find { |locale| LocaleNormalizer.is_same?(locale, base) } ||
          LocaleNormalizer.normalize_to_i18n(base)
      end
    end
  end
end

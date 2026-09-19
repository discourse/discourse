# frozen_string_literal: true

module DiscourseAi
  module Agents
    class EmotionClassifier < Agent
      def self.default_enabled
        false
      end

      def system_prompt
        <<~PROMPT
          You classify Discourse forum posts by emotion.

          Return a probability score for every supported emotion label. Each score must be a float from 0 to 1. The scores must sum to 1.0. Higher scores mean the label is more applicable to the post.

          Classify the author's emotions, not quoted text or replies from other people. Ignore markup, links, signatures, logs, and code blocks unless they clearly express emotion. Interpret sarcasm and irony by their implied meaning.

          Multiple emotions can share probability mass, but the scores must still sum to 1.0. Use neutral as the highest score for factual announcements, questions, or technical debugging with little affect.

          Use the full post content provided by the user. Reply with valid JSON only. Do not include explanations, confidence fields, or any keys except the supported emotion labels.
        PROMPT
      end

      def response_format
        DiscourseAi::Sentiment::Emotions::LIST.map do |label|
          { "key" => label, "type" => "number" }
        end
      end

      def examples
        [
          [
            "Thank you for the detailed walkthrough. This solved my issue and saved me a lot of time.",
            emotion_scores(
              gratitude: 0.72,
              admiration: 0.14,
              approval: 0.08,
              relief: 0.04,
              neutral: 0.02,
            ),
          ],
          [
            "This keeps failing after every deploy. I am frustrated that the same bug came back again.",
            emotion_scores(
              annoyance: 0.42,
              anger: 0.25,
              disappointment: 0.18,
              disapproval: 0.1,
              neutral: 0.05,
            ),
          ],
          [
            "Does anyone know why this setting disappeared after the migration?",
            emotion_scores(
              curiosity: 0.46,
              confusion: 0.32,
              surprise: 0.12,
              neutral: 0.08,
              realization: 0.02,
            ),
          ],
          [
            "I am sorry for deleting the topic by mistake. I should have checked before clicking.",
            emotion_scores(
              remorse: 0.68,
              embarrassment: 0.16,
              sadness: 0.08,
              disappointment: 0.05,
              neutral: 0.03,
            ),
          ],
          [
            "Great, now the backup is gone too. That is exactly what I needed today.",
            emotion_scores(
              annoyance: 0.35,
              anger: 0.22,
              disappointment: 0.2,
              disapproval: 0.12,
              sadness: 0.06,
              neutral: 0.05,
            ),
          ],
          [
            "I cannot believe how quickly this was fixed. The new workflow is a joy to use.",
            emotion_scores(
              joy: 0.42,
              admiration: 0.2,
              approval: 0.16,
              surprise: 0.12,
              excitement: 0.08,
              neutral: 0.02,
            ),
          ],
          [
            "I am worried the importer may lose attachments if we run it before the patch is ready.",
            emotion_scores(
              fear: 0.38,
              nervousness: 0.24,
              curiosity: 0.12,
              confusion: 0.1,
              neutral: 0.1,
              sadness: 0.06,
            ),
          ],
        ]
      end

      private

      def emotion_scores(overrides)
        DiscourseAi::Sentiment::Emotions::LIST
          .index_with { |label| overrides[label.to_sym] || 0.0 }
          .to_json
      end
    end
  end
end

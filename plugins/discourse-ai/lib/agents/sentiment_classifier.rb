# frozen_string_literal: true

module DiscourseAi
  module Agents
    class SentimentClassifier < Agent
      def self.default_enabled
        false
      end

      def system_prompt
        <<~PROMPT
          You classify Discourse forum posts by sentiment.

          Return a probability score for each sentiment label:
          - negative
          - neutral
          - positive

          Each score must be a float from 0 to 1. The scores must sum to 1.0. Higher scores mean the label is more applicable to the post.

          Classify the author's sentiment, not quoted text or replies from other people. Ignore markup, links, signatures, logs, and code blocks unless they clearly express sentiment. Interpret sarcasm and irony by their implied meaning.

          Use neutral as the highest score for factual announcements, questions, or technical debugging with little affect. For mixed sentiment, distribute probability across labels instead of forcing a single winner.

          Use the full post content provided by the user. Reply with valid JSON only. Do not include explanations, confidence fields, or any keys except the sentiment labels.
        PROMPT
      end

      def response_format
        %w[negative neutral positive].map { |label| { "key" => label, "type" => "number" } }
      end

      def examples
        [
          [
            "This release is fantastic. The new editor is fast, polished, and much easier to use.",
            { negative: 0.02, neutral: 0.08, positive: 0.9 }.to_json,
          ],
          [
            "The upgrade broke search for our team and the workaround did not help.",
            { negative: 0.88, neutral: 0.09, positive: 0.03 }.to_json,
          ],
          [
            "Version 3.2 is now available in the admin updates page.",
            { negative: 0.03, neutral: 0.92, positive: 0.05 }.to_json,
          ],
        ]
      end
    end
  end
end

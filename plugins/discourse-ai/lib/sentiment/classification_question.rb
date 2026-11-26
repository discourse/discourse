# frozen_string_literal: true

module DiscourseAi
  module Sentiment
    class ClassificationQuestion
      def self.for(classification_type)
        sentiment = classification_type.to_s == "sentiment"
        subject = sentiment ? "sentiment" : "emotions"
        instructions = <<~PROMPT
          Classify the author's #{subject} in this Discourse forum post, not quoted text or replies from other people.
          Ignore markup, links, signatures, logs, and code blocks unless they clearly express #{subject}.
          Interpret sarcasm and irony by their implied meaning.
          Use neutral as the highest probability for factual announcements, questions, or technical debugging with little affect.
          For mixed #{subject}, distribute probability across labels instead of forcing a single winner.
          Use the full post content provided. The label probabilities must sum to 1.0.
        PROMPT

        DiscourseAi::Decisions::Question.new(
          name: classification_type.to_s,
          type: :choice,
          instructions: instructions,
          choices: sentiment ? %w[negative neutral positive] : Emotions::LIST,
        )
      end
    end
  end
end

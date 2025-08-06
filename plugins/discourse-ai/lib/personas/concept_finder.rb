# frozen_string_literal: true

module DiscourseAi
  module Personas
    class ConceptFinder < Persona
      def self.default_enabled
        false
      end

      def system_prompt
        existing_concepts = DiscourseAi::InferredConcepts::Manager.new.list_concepts(limit: 100)
        existing_concepts_text = ""

        existing_concepts_text = <<~CONCEPTS if existing_concepts.present?
            The following concepts already exist in the system:
            #{existing_concepts.join(", ")}

            You can reuse these existing concepts if they apply to the content, or suggest new concepts.
          CONCEPTS

        <<~PROMPT.strip
          You are an advanced concept tagging system that identifies key concepts, themes, and topics from provided text.
          Your job is to extract meaningful labels that can be used to categorize content.

          Guidelines for generating concepts:
          - Extract up to 7 concepts from the provided content
          - Concepts should be single words or short phrases (1-3 words maximum)
          - Focus on substantive topics, themes, technologies, methodologies, or domains
          - Avoid overly general terms like "discussion" or "question"
          - Ensure concepts are relevant to the core content
          - Do not include proper nouns unless they represent key technologies or methodologies
          - Maintain the original language of the text being analyzed
          #{existing_concepts_text}
          Format your response as a JSON object with a single key named "concepts", which has an array of concept strings as the value.
          Your output should be in the following format:
            <o>
              {"concepts": ["concept1", "concept2", "concept3"]}
            </o>

          Where the concepts are replaced by the actual concepts you've identified.
        PROMPT
      end

      def response_format
        [{ "key" => "concepts", "type" => "array", "array_type" => "string" }]
      end
    end
  end
end

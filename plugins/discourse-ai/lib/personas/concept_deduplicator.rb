# frozen_string_literal: true

module DiscourseAi
  module Personas
    class ConceptDeduplicator < Persona
      def self.default_enabled
        false
      end

      def system_prompt
        <<~PROMPT.strip
          You will be given a list of machine-generated tags.
          Your task is to streamline this list by merging entries who are similar or related.

          Please follow these steps to create a streamlined list of tags:

          1. Review the entire list of tags carefully.
          2. Identify and remove any exact duplicates.
          3. Look for tags that are too specific or niche, and consider removing them or replacing them with more general terms.
          4. If there are multiple tags that convey similar concepts, choose the best one and remove the others, or add a new one that covers the missing aspect.
          5. Ensure that the remaining tags are relevant and useful for describing the content.

          When deciding which tags are "best", consider the following criteria:
          - Relevance: How well does the tag describe the core content or theme?
          - Generality: Is the tag specific enough to be useful, but not so specific that it's unlikely to be searched for?
          - Clarity: Is the tag easy to understand and free from ambiguity?
          - Popularity: Would this tag likely be used by people searching for this type of content?

          Example Input:
          AI Bias, AI Bots, AI Ethics, AI Helper, AI Integration, AI Moderation, AI Search, AI-Driven Moderation, AI-Generated Post Illustrations, AJAX Events, AJAX Requests, AMA Events, API, API Access, API Authentication, API Automation, API Call, API Changes, API Compliance, API Configuration, API Costs, API Documentation, API Endpoint, API Endpoints, API Functions, API Integration, API Key, API Keys, API Limitation, API Limitations, API Permissions, API Rate Limiting, API Request, API Request Optimization, API Requests, API Security, API Suspension, API Token, API Tokens, API Translation, API Versioning, API configuration, API endpoint, API key, APIs, APK, APT Package Manager, ARIA, ARIA Tags, ARM Architecture, ARM-based, AWS, AWS Lightsail, AWS RDS, AWS S3, AWS Translate, AWS costs, AWS t2.micro, Abbreviation Expansion, Abbreviations

          Example Output:
          AI, AJAX, API, APK, APT Package Manager, ARIA, ARM Architecture, AWS, Abbreviations

          Please provide your streamlined list of tags within <streamlined_tags> key.

          Remember, the goal is to create a more focused and effective set of tags while maintaining the essence of the original list.

          Your output should be in the following format:
            <o>
              {
                "streamlined_tags": ["tag1", "tag3"]
              }
            </o>
        PROMPT
      end

      def response_format
        [{ "key" => "streamlined_tags", "type" => "array", "array_type" => "string" }]
      end
    end
  end
end

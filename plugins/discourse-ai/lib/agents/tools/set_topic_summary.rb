# frozen_string_literal: true

module DiscourseAi
  module Agents
    module Tools
      class SetTopicSummary < Tool
        MAX_SUMMARY_LENGTH = 1_000

        def self.signature
          {
            name: name,
            description: "Sets the final short topic summary",
            parameters: [
              {
                name: "summary",
                description: "The final topic summary, in no more than 40 words",
                type: "string",
                required: true,
              },
            ],
          }
        end

        def self.name
          "set_topic_summary"
        end

        def invoke
          @summary = parameters[:summary].to_s.strip

          if @summary.blank?
            @summary = nil
            return error_response("The topic summary must not be blank")
          elsif @summary.length > MAX_SUMMARY_LENGTH
            @summary = nil
            return error_response("The topic summary is too long")
          end

          { status: "success" }
        end

        def custom_raw
          @summary
        end

        def chain_next_response?
          @summary.blank?
        end
      end
    end
  end
end

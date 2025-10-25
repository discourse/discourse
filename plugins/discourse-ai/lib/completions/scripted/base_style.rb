# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Scripted
      class BaseStyle
        def self.can_handle?(_llm_config)
          raise NotImplementedError
        end

        def initialize(raw_responses, llm_model)
          @raw_responses = raw_responses
          @llm_model = llm_model
          @last_request = nil
        end

        def request(request)
          @last_request = request
          response = build_response(request)

          if block_given?
            yield response
          else
            response
          end
        end

        def finish
          # Cleanup test-specific data.
          @last_request = nil
          # no-op; parity with Net::HTTP interface
        end

        attr_reader :last_request

        private

        attr_reader :raw_responses, :llm_model

        def build_response(_request)
          raise NotImplementedError
        end
      end
    end
  end
end

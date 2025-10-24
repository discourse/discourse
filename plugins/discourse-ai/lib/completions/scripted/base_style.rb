# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Scripted
      class BaseStyle
        def self.can_handle?(_llm_config)
          raise NotImplementedError
        end

        def initialize(raw_responses)
          @raw_responses = raw_responses
        end

        def request(request)
          response = build_response(request)

          if block_given?
            yield response
          else
            response
          end
        end

        def finish
          # no-op; parity with Net::HTTP interface
        end

        private

        attr_reader :raw_responses

        def build_response
          raise NotImplementedError
        end
      end
    end
  end
end

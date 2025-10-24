# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Scripted
      class Response
        attr_reader :code, :body

        def initialize(body: nil, status: 200, streaming_mode: false)
          @body = body
          @code = status.to_s
          @streaming_mode = streaming_mode
        end

        def read_body
          if streaming_mode
            body.to_a.each { |chunk| yield chunk }
          else
            body
          end
        end

        private

        attr_reader :streaming_mode
      end
    end
  end
end

# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Scripted
      class Response
        attr_reader :code

        def initialize(body: nil, status: 200, chunks: nil)
          @body = body
          @code = status.to_s
          @chunks = chunks
        end

        def read_body
          if @chunks
            @chunks.each { |chunk| yield chunk }
          else
            if block_given?
              yield @body
            else
              @body
            end
          end
        end

        def body
          return @body if @body
          return "" if !@chunks

          @chunks.join
        end
      end
    end
  end
end

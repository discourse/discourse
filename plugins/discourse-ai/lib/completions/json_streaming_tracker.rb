# frozen_string_literal: true

module DiscourseAi
  module Completions
    class JsonStreamingTracker
      attr_reader :current_key, :current_value, :stream_consumer

      def initialize(stream_consumer)
        @stream_consumer = stream_consumer
        @current_key = nil
        @current_value = nil
        @tracking_array = false
        @parser = DiscourseAi::Completions::JsonStreamingParser.new

        @parser.key do |k|
          @current_key = k
          @current_value = nil
        end

        @parser.value do |value|
          if @current_key
            if @tracking_array
              @current_value << value
              stream_consumer.notify_progress(@current_key, @current_value)
            else
              stream_consumer.notify_progress(@current_key, value)
              @current_key = nil
            end
          end
        end

        @parser.start_array do
          @tracking_array = true
          @current_value = []
        end

        @parser.end_array do
          @tracking_array = false
          @current_key = nil
          @current_value = nil
        end
      end

      def broken?
        @broken
      end

      def <<(raw_json)
        # llm could send broken json
        # in that case just deal with it later
        # don't stream
        return if @broken

        begin
          pre_append_buffer = @parser.buf.dup
          @parser << raw_json
        rescue DiscourseAi::Completions::ParserError
          # Note: We're parsing JSON content that was itself embedded as a string inside another JSON object.
          # During the outer JSON.parse, any escaped control characters (like "\\n") are unescaped to real characters ("\n"),
          # which corrupts the inner JSON structure when passed to the parser here.
          # To handle this, we retry parsing with the string JSON-escaped again (`.dump[1..-2]`) if the first attempt fails.
          try_escape_and_parse(raw_json, pre_append_buffer)
          return if @broken
        end

        if @parser.state == :start_string && @current_key
          buffered = @tracking_array ? [@parser.buf] : @parser.buf
          # this is is worth notifying
          stream_consumer.notify_progress(@current_key, buffered)
        end

        @current_key = nil if @parser.state == :end_value
      end

      private

      def try_escape_and_parse(raw_json, pre_append_buffer)
        if !raw_json.is_a?(String)
          @broken = true
          return
        end
        # Escape the string as JSON and remove surrounding quotes
        escaped_json = raw_json.dump[1..-2]

        # Assume we could have already processed some of the chunk which was stored in the parser's buffer.
        already_processed_chunk = @parser.buf
        last_seen_char_idx = already_processed_chunk.length - pre_append_buffer.length

        escaped_json = escaped_json[last_seen_char_idx..]

        @parser << escaped_json
      rescue DiscourseAi::Completions::ParserError
        @broken = true
      end
    end
  end
end

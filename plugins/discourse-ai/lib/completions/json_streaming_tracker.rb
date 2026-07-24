# frozen_string_literal: true

module DiscourseAi
  module Completions
    class JsonStreamingTracker
      attr_reader :stream_consumer

      def initialize(stream_consumer)
        @stream_consumer = stream_consumer
        @escaped_buffer = +""
        @completer = JsonCompleter.new
        @broken = false
        @last_notified = {}
      end

      def broken?
        @broken
      end

      def <<(raw_json)
        return if @broken

        if !raw_json.is_a?(String)
          @broken = true
          return
        end

        @escaped_buffer << DiscourseAi::Utils::BestEffortJsonParser.escape_control_characters(
          raw_json,
        )

        parsed =
          begin
            @completer.parse(@escaped_buffer)
          rescue JsonCompleter::ParseError
            @broken = true
            return
          end

        notify_changes(parsed) if parsed.is_a?(Hash)
      end

      private

      def notify_changes(parsed)
        parsed.each do |key, value|
          next if value.nil?
          next if @last_notified[key] == value

          # the completer mutates parsed containers in place between calls, so
          # compare against a snapshot
          @last_notified[key] = value.deep_dup
          stream_consumer.notify_progress(key, value)
        end
      end
    end
  end
end

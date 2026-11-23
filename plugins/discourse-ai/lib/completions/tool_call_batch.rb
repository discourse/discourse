# frozen_string_literal: true

module DiscourseAi
  module Completions
    class ToolCallBatch
      # Report whole unfinished batches: a partial set of results is not replayable.
      def self.each_incomplete_index(messages, keep_pending: false)
        return enum_for(__method__, messages, keep_pending: keep_pending) unless block_given?

        batch = new
        indices = []
        messages.each_with_index do |message, index|
          # Prompt discards late system messages. They do not end a tool batch.
          next if message[:type] == :system

          if batch.accept?(message)
            indices << index
            indices.clear unless batch.open?
          else
            indices.each { |entry_index| yield entry_index }
            yield index if tool_message?(message)
            batch.reset
            indices.clear
          end
        end
        indices.each { |index| yield index } unless keep_pending
      end

      def self.tool_message?(message)
        %i[tool_call tool].include?(message&.dig(:type))
      end

      # A batch has one run of calls, followed by one run of results. Do not walk
      # earlier completed pairs when appending to a prompt with many serial calls.
      def self.trailing_start(messages)
        start = messages.length
        start -= 1 while start > 0 && messages[start - 1][:type] == :tool
        start -= 1 while start > 0 && messages[start - 1][:type] == :tool_call
        start
      end

      def initialize
        @pending = {}
        reset
      end

      def reset
        @pending.clear
        @receiving_results = false
      end

      def open?
        !@pending.empty?
      end

      def accept?(message)
        return false unless self.class.tool_message?(message)

        # Some providers pair by name. Never treat a name as an explicit ID.
        key =
          if message[:id].present?
            [:id, message[:id].to_s]
          elsif message[:name].present?
            [:name, message[:name].to_s]
          end
        return false unless key

        if message[:type] == :tool_call
          return false if @receiving_results || @pending.key?(key)
          @pending[key] = true
        else
          return false unless @pending.delete(key)
          @receiving_results = open?
        end
        true
      end
    end
  end
end

# frozen_string_literal: true

module DiscourseAi
  class AiApiAuditLogResponseDecoder
    MAX_INPUT_BYTES = 1.megabyte

    Result =
      Struct.new(:response, :decoded, keyword_init: true) do
        def decoded?
          decoded
        end
      end

    def self.decode(raw_response_payload, truncated: false)
      new(raw_response_payload, truncated:).decode
    end

    def initialize(raw_response_payload, truncated:)
      @raw_response_payload = raw_response_payload
      @truncated = truncated
      @reasoning_fragments = []
      @answer_fragments = []
    end

    def decode
      return fallback if invalid_input?

      events = parse_events
      return fallback if events.nil?

      details =
        DiscourseAi::AiApiAuditLogStreamDetailsExtractor.extract(
          events,
          stream_terminated: @stream_terminated,
        )
      return fallback if details.invalid?

      events.each { |event| extract_fragments(event) }

      reasoning = @reasoning_fragments.join
      answer = @answer_fragments.join
      if reasoning.blank? && answer.blank? && details.tool_calls.empty? &&
           details.tool_results.empty?
        return fallback
      end

      response = decoded_response(reasoning, answer, details)

      Result.new(response:, decoded: true)
    rescue JSON::ParserError, TypeError, ArgumentError
      fallback
    end

    private

    def decoded_response(reasoning, answer, details)
      return answer if reasoning.blank? && details.tool_calls.empty? && details.tool_results.empty?

      {
        "thinking" => reasoning.presence,
        "tool_calls" => details.tool_calls.presence,
        "tool_results" => details.tool_results.presence,
        "response" => answer.presence,
      }.compact.to_json
    end

    def fallback
      Result.new(response: @raw_response_payload, decoded: false)
    end

    def invalid_input?
      @truncated || !@raw_response_payload.is_a?(String) || @raw_response_payload.blank? ||
        !@raw_response_payload.valid_encoding? || @raw_response_payload.bytesize > MAX_INPUT_BYTES
    end

    def parse_events
      if sse_transport?
        parse_sse
      else
        parse_newline_delimited_json
      end
    end

    def sse_transport?
      @raw_response_payload.each_line.any? do |line|
        line.match?(/\A(?:data|event):/) || line.start_with?(":")
      end
    end

    def parse_sse
      events = []
      record_lines = []
      done = false
      valid = true

      @raw_response_payload
        .split(/\r?\n/, -1)
        .each do |line|
          if line.empty?
            parsed_record = parse_sse_record(record_lines)
            if parsed_record == :invalid
              valid = false
              break
            end

            if parsed_record == :done
              done = true
            elsif parsed_record
              if done
                valid = false
                break
              end

              events << parsed_record
            end
            record_lines = []
          else
            record_lines << line
          end
        end

      return if !valid || record_lines.present?
      @stream_terminated = done
      return if events.empty?

      events
    end

    def parse_sse_record(lines)
      return if lines.empty?

      data_lines = []
      lines.each do |line|
        next if line.start_with?(":")

        field, value = line.split(":", 2)
        return :invalid if value.nil? || !%w[data event].include?(field)

        value = value.delete_prefix(" ")
        data_lines << value if field == "data"
      end

      return if data_lines.empty?

      data = data_lines.join("\n")
      return :done if data.strip == "[DONE]"

      parsed = JSON.parse(data)
      parsed.is_a?(Hash) ? parsed : :invalid
    end

    def parse_newline_delimited_json
      lines = @raw_response_payload.lines(chomp: true).reject(&:blank?)
      return if lines.length < 2

      events = lines.map { |line| JSON.parse(line) }
      return if !events.all? { |event| event.is_a?(Hash) }

      events
    end

    def extract_fragments(event)
      extract_open_ai_chat(event)
      extract_open_ai_response(event)
      extract_anthropic(event)
      extract_gemini(event)
      extract_gemini_interaction(event)
      extract_ollama(event)
      extract_cohere(event)
    end

    def extract_open_ai_chat(event)
      choices = event["choices"]
      return if !choices.is_a?(Array)

      choices.each do |choice|
        delta = choice.is_a?(Hash) ? choice["delta"] : nil
        next if !delta.is_a?(Hash)

        reasoning =
          if delta["reasoning"].is_a?(String)
            delta["reasoning"]
          elsif delta["reasoning_content"].is_a?(String)
            delta["reasoning_content"]
          end
        append(@reasoning_fragments, reasoning)
        append(@answer_fragments, delta["content"])
      end
    end

    def extract_open_ai_response(event)
      case event["type"]
      when "response.reasoning_summary_text.delta"
        append(@reasoning_fragments, event["delta"])
      when "response.output_text.delta"
        append(@answer_fragments, event["delta"])
      end
    end

    def extract_anthropic(event)
      case event["type"]
      when "content_block_start"
        content_block = event["content_block"]
        return if !content_block.is_a?(Hash)

        case content_block["type"]
        when "thinking"
          append(@reasoning_fragments, content_block["thinking"])
        when "text"
          append(@answer_fragments, content_block["text"])
        end
      when "content_block_delta"
        delta = event["delta"]
        return if !delta.is_a?(Hash)

        case delta["type"]
        when "thinking_delta"
          append(@reasoning_fragments, delta["thinking"])
        when "text_delta"
          append(@answer_fragments, delta["text"])
        end
      end
    end

    def extract_gemini(event)
      candidates = event["candidates"]
      return if !candidates.is_a?(Array)

      candidates.each do |candidate|
        parts = candidate.is_a?(Hash) ? candidate.dig("content", "parts") : nil
        next if !parts.is_a?(Array)

        parts.each do |part|
          next if !part.is_a?(Hash)

          fragments = part["thought"] == true ? @reasoning_fragments : @answer_fragments
          append(fragments, part["text"])
        end
      end
    end

    def extract_gemini_interaction(event)
      return if event["event_type"] != "step.delta"

      delta = event["delta"]
      return if !delta.is_a?(Hash)

      case delta["type"]
      when "thought_summary"
        content = delta["content"]
        append(@reasoning_fragments, content["text"]) if content.is_a?(Hash)
      when "text"
        append(@answer_fragments, delta["text"])
      end
    end

    def extract_ollama(event)
      message = event["message"]
      return if !message.is_a?(Hash)

      append(@reasoning_fragments, message["thinking"])
      append(@answer_fragments, message["content"])
    end

    def extract_cohere(event)
      case event["event_type"]
      when "text-generation"
        append(@answer_fragments, event["text"])
      when "tool-calls-generation"
        append(@reasoning_fragments, event["text"])
      end
    end

    def append(fragments, value)
      fragments << value if value.is_a?(String) && !value.empty?
    end
  end
end

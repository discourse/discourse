# frozen_string_literal: true

module DiscourseAi
  module Completions
    class GeminiInteractionsMessageProcessor
      PROVIDER_KEY = :gemini_interactions
      NATIVE_CALL_TYPES = %w[
        code_execution_call
        file_search_call
        google_maps_call
        google_search_call
        url_context_call
      ].freeze
      NATIVE_RESULT_TYPES = %w[
        code_execution_result
        file_search_result
        google_maps_result
        google_search_result
        url_context_result
      ].freeze

      attr_reader :prompt_tokens, :completion_tokens, :cache_read_tokens

      def initialize(partial_tool_calls: false, output_thinking: false, &content_decoder)
        @partial_tool_calls = partial_tool_calls
        @output_thinking = output_thinking
        @content_decoder = content_decoder
        @pending_steps = []
        @current_step = nil
        @tool_arguments = +""
        @streaming_parser = nil
        @has_new_tool_data = false
        @emitted_google_maps_citations = Set.new
      end

      def process_message(payload)
        payload = normalize(payload)
        result = []

        Array(payload[:steps]).each { |step| result.concat(process_complete_step(step)) }
        update_usage(payload[:usage])
        result.concat(flush_pending_steps)
        result.compact
      end

      def process_streamed_message(event)
        event = normalize(event)
        result = []

        case event[:event_type]
        when "step.start"
          result.concat(start_step(event[:step]))
        when "step.delta"
          result.concat(process_delta(event[:delta]))
        when "step.stop"
          result.concat(finish_current_step(event[:step]))
        end

        update_usage(event.dig(:interaction, :usage) || event.dig(:metadata, :total_usage))
        result.compact
      end

      def notify_progress(key, value)
        return if !@current_tool

        @current_tool.partial = true
        @current_tool.parameters[key.to_sym] = value
        @has_new_tool_data = true
      end

      def finish
        result = finish_current_step
        result.concat(flush_pending_steps)
        result.compact
      end

      private

      def process_complete_step(step)
        step = normalize(step)
        type = step[:type]

        case type
        when "thought"
          @pending_steps << step.deep_dup
          thought_outputs(step, partial: false)
        when "function_call"
          [tool_call_from_step(step, replay_steps: consume_pending_steps + [step.deep_dup])]
        when "model_output"
          decode_model_output(step[:content])
        when *NATIVE_CALL_TYPES, *NATIVE_RESULT_TYPES
          @pending_steps << step.deep_dup
          native_tool_outputs(step)
        else
          @pending_steps << step.deep_dup if type.present?
          []
        end
      end

      def start_step(step)
        @current_step = normalize(step || {}).deep_dup
        @current_step[:content] = [] if @current_step[:type] == "model_output"

        return [] if @current_step[:type] != "function_call"

        initial_arguments = @current_step[:arguments]
        @tool_arguments =
          if initial_arguments.is_a?(String)
            +initial_arguments
          elsif initial_arguments.present?
            +initial_arguments.to_json
          else
            +""
          end
        @current_tool =
          ToolCall.new(id: @current_step[:id], name: @current_step[:name], parameters: {})
        @streaming_parser = JsonStreamingTracker.new(self) if @partial_tool_calls
        @streaming_parser << @tool_arguments if @streaming_parser && @tool_arguments.present?
        current_tool_progress
      end

      def process_delta(delta)
        delta = normalize(delta || {})
        type = delta[:type]

        case type
        when "text"
          append_content_delta(delta)
          [delta[:text].presence, *google_maps_attribution_outputs([delta])]
        when "image", "audio", "video", "document"
          append_content_delta(delta)
          decode_content([delta])
        when "thought_signature"
          @current_step[:signature] = delta[:signature] if @current_step
          []
        when "thought_summary"
          append_thought_summary(delta[:content])
          thought_summary_delta(delta[:content])
        when "arguments", "arguments_delta"
          process_arguments_delta(delta[:arguments] || delta[:partial_arguments])
        when *NATIVE_CALL_TYPES, *NATIVE_RESULT_TYPES
          @current_step&.deep_merge!(delta)
          []
        else
          []
        end
      end

      def append_content_delta(delta)
        return if !@current_step

        content = delta.except(:type).merge(type: delta[:type])
        @current_step[:content] ||= []
        if content[:type] == "text" && @current_step[:content].last&.dig(:type) == "text"
          @current_step[:content].last[:text] = @current_step[:content].last[:text].to_s +
            content[:text].to_s
        else
          @current_step[:content] << content
        end
      end

      def append_thought_summary(content)
        return if !@current_step || content.blank?

        @current_step[:summary] ||= []
        normalized_content = normalize(content)
        if thought_summary_text?(normalized_content) &&
             thought_summary_text?(@current_step[:summary].last)
          @current_step[:summary].last[:text] = @current_step[:summary].last[:text].to_s +
            normalized_content[:text].to_s
        else
          @current_step[:summary] << normalized_content
        end
      end

      def thought_summary_delta(content)
        return [] if !@output_thinking

        text = normalize(content || {})[:text]
        text.present? ? [Thinking.new(message: text, partial: true)] : []
      end

      def process_arguments_delta(arguments)
        return [] if arguments.nil?

        fragment = arguments.is_a?(String) ? arguments : arguments.to_json
        @tool_arguments << fragment
        @streaming_parser << fragment if @streaming_parser
        current_tool_progress
      end

      def current_tool_progress
        return [] if !@has_new_tool_data

        @has_new_tool_data = false
        [@current_tool.dup]
      end

      def finish_current_step(final_step = nil)
        return [] if @current_step.blank? && final_step.blank?

        step = @current_step || {}
        step = step.deep_merge(normalize(final_step)) if final_step.present?
        type = step[:type]
        result = []

        case type
        when "thought"
          @pending_steps << step.deep_dup
          result.concat(thought_outputs(step, partial: false))
        when "function_call"
          step[:arguments] = parsed_tool_arguments(step)
          result << tool_call_from_step(step, replay_steps: consume_pending_steps + [step.deep_dup])
        when "model_output"
          # Text is emitted by deltas; annotations can arrive only with the completed step.
          result.concat(google_maps_attribution_outputs(step[:content]))
        when *NATIVE_CALL_TYPES, *NATIVE_RESULT_TYPES
          @pending_steps << step.deep_dup
          result.concat(native_tool_outputs(step))
        else
          @pending_steps << step.deep_dup if type.present?
        end

        reset_current_step
        result.compact
      end

      def parsed_tool_arguments(step)
        return step[:arguments] || {} if @tool_arguments.blank?

        ToolArgumentsParser.parse(@tool_arguments)
      rescue JSON::ParserError
        {}
      end

      def reset_current_step
        @current_step = nil
        @current_tool = nil
        @tool_arguments = +""
        @streaming_parser = nil
        @has_new_tool_data = false
      end

      def tool_call_from_step(step, replay_steps:)
        ToolCall.new(
          id: step[:id],
          name: step[:name],
          parameters: normalize(step[:arguments] || {}),
          provider_data: {
            PROVIDER_KEY => {
              steps: replay_steps,
            },
          },
        )
      end

      def thought_outputs(step, partial:)
        return [] if !@output_thinking

        message =
          Array(step[:summary])
            .filter_map do |content|
              content = normalize(content)
              if thought_summary_text?(content)
                content[:text]
              else
                @content_decoder.call(content)&.strip
              end
            end
            .join("\n\n")
        message.present? ? [Thinking.new(message:, partial:)] : []
      end

      def thought_summary_text?(content)
        content.present? && (content[:type].blank? || content[:type] == "text")
      end

      def native_tool_outputs(step)
        return [] if !@output_thinking || NATIVE_CALL_TYPES.exclude?(step[:type])

        message =
          case step[:type]
          when "google_search_call"
            queries = Array(step.dig(:arguments, :queries)).compact_blank
            queries.present? ? "Web search: #{queries.join(", ")}" : "Web search"
          when "url_context_call"
            urls = Array(step.dig(:arguments, :urls)).compact_blank
            urls.present? ? "Web fetch: #{urls.join(", ")}" : "Web fetch"
          when "code_execution_call"
            code_execution_message(step)
          when "file_search_call"
            "File search"
          when "google_maps_call"
            "Google Maps search"
          end

        [Thinking.new(message:, partial: false)]
      end

      def decode_model_output(content)
        outputs = decode_content(content)
        attribution = google_maps_attribution_outputs(content).join
        return outputs if attribution.blank?

        last_text_index = outputs.rindex { |output| output.is_a?(String) }
        if last_text_index
          outputs[last_text_index] += attribution
        else
          outputs << attribution
        end
        outputs
      end

      def code_execution_message(step)
        code = step.dig(:arguments, :code).to_s
        return "Code execution" if code.blank?

        language = step.dig(:arguments, :language).to_s.downcase
        language = "" if !language.match?(/\A[a-z0-9_+-]+\z/)
        longest_backtick_run = code.scan(/`+/).map(&:length).max.to_i
        fence = "`" * [3, longest_backtick_run + 1].max

        "Code execution:\n\n#{fence}#{language}\n#{code.rstrip}\n#{fence}"
      end

      def google_maps_attribution_outputs(content)
        links =
          Array(content).flat_map do |item|
            item = normalize(item)
            Array(item[:annotations]).filter_map do |annotation|
              annotation = normalize(annotation)
              next if annotation[:type] != "place_citation"

              name = annotation[:name].to_s
              url = annotation[:url].to_s
              next if name.blank? || !url.start_with?("https://")

              citation_key = [name, url]
              next if @emitted_google_maps_citations.include?(citation_key)

              @emitted_google_maps_citations << citation_key
              "[#{escape_markdown_link_text(name)}](#{url})"
            end
          end

        links.present? ? ["\n\nGoogle Maps: #{links.join(", ")}"] : []
      end

      def escape_markdown_link_text(text)
        text.gsub(/[\\\[\]]/) { |character| "\\#{character}" }
      end

      def decode_content(content)
        Array(content).filter_map { |item| @content_decoder.call(normalize(item)) }
      end

      def context_thinking(steps)
        return if steps.blank?

        # Stateless continuation requires signed steps even when thinking is hidden.
        Thinking.new(message: nil, partial: false, provider_info: { PROVIDER_KEY => { steps: } })
      end

      def flush_pending_steps
        steps = consume_pending_steps
        steps.present? ? [context_thinking(steps)] : []
      end

      def consume_pending_steps
        steps = @pending_steps
        @pending_steps = []
        steps
      end

      def update_usage(usage)
        return if usage.blank?

        usage = normalize(usage)
        cached = usage[:total_cached_tokens].to_i
        @prompt_tokens = [usage[:total_input_tokens].to_i - cached, 0].max
        @cache_read_tokens = cached
        # Gemini reports generated, thought, and tool-use output separately.
        @completion_tokens =
          usage[:total_output_tokens].to_i + usage[:total_thought_tokens].to_i +
            usage[:total_tool_use_tokens].to_i
      end

      def normalize(value)
        value.respond_to?(:deep_symbolize_keys) ? value.deep_symbolize_keys : value
      end
    end
  end
end

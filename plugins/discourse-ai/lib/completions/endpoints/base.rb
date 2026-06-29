# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Endpoints
      class Base
        attr_reader :partial_tool_calls, :output_thinking

        CompletionFailed = Class.new(StandardError)
        FAIL_THRESHOLD = 5
        FAIL_TTL = 1.hour
        # Applies to both synchronous and background completions; keep retry waits bounded
        # and interruptible via sleep_before_retry.
        RATE_LIMIT_RETRY_DELAYS = [2, 8, 16]
        RETRY_JITTER_MAX_SECONDS = 1.0
        TRANSIENT_ERROR_RETRY_DELAYS = [0.5, 1.0]
        MAX_RETRY_AFTER_SECONDS = 60
        # Stored in AiApiAuditLog#request_attempts for retried network failures,
        # which do not have an HTTP status code. 0 is intentionally outside the HTTP range.
        NETWORK_ERROR_RETRY_STATUS = 0
        RETRIABLE_NETWORK_ERRORS = [
          Net::OpenTimeout,
          Net::ReadTimeout,
          Errno::ECONNREFUSED,
          Errno::ECONNRESET,
          Errno::ETIMEDOUT,
          SocketError,
          OpenSSL::SSL::SSLError,
        ]

        # Read-only context handed to request header providers. Lets plugins
        # contribute provider-agnostic, per-request HTTP headers (e.g. routing
        # hints for a proxy) without reaching into endpoint internals.
        RequestHeaderContext =
          Struct.new(
            :llm_model,
            :feature_name,
            :feature_context,
            :has_images,
            :streaming,
            keyword_init: true,
          )

        # Mutated in place (<<, clear) but never reassigned, so the single array
        # is shared across Base and all endpoint subclasses via constant lookup.
        REQUEST_HEADERS_PROVIDERS = []
        # 6 minutes
        # Reasoning LLMs can take a very long time to respond, generally it will be under 5 minutes
        # The alternative is to have per LLM timeouts but that would make it extra confusing for people
        # configuring. Let's try this simple solution first.
        TIMEOUT = 360

        class << self
          def endpoint_for(llm_model)
            endpoints = [
              DiscourseAi::Completions::Endpoints::AwsBedrockConverse,
              DiscourseAi::Completions::Endpoints::AwsBedrock,
              DiscourseAi::Completions::Endpoints::OpenAi,
              DiscourseAi::Completions::Endpoints::OpenAiResponses,
              DiscourseAi::Completions::Endpoints::HuggingFace,
              DiscourseAi::Completions::Endpoints::Gemini,
              DiscourseAi::Completions::Endpoints::Vllm,
              DiscourseAi::Completions::Endpoints::Anthropic,
              DiscourseAi::Completions::Endpoints::Cohere,
              DiscourseAi::Completions::Endpoints::SambaNova,
              DiscourseAi::Completions::Endpoints::Mistral,
              DiscourseAi::Completions::Endpoints::OpenRouter,
            ]

            endpoints << DiscourseAi::Completions::Endpoints::Ollama if !Rails.env.production?

            endpoints << DiscourseAi::Completions::Endpoints::Fake if Rails.env.local?

            endpoints.detect(-> { raise DiscourseAi::Completions::Llm::UNKNOWN_MODEL }) do |ek|
              ek.can_contact?(llm_model)
            end
          end

          def can_contact?(_llm_model)
            raise NotImplementedError
          end

          # Register a block that returns a Hash of extra HTTP headers to send
          # with each completion request. The block receives a
          # RequestHeaderContext and must not raise (errors are swallowed and
          # logged so a header bug can never break inference).
          def register_request_headers_provider(&block)
            REQUEST_HEADERS_PROVIDERS << block
          end

          def request_headers_providers
            REQUEST_HEADERS_PROVIDERS
          end

          def reset_request_headers_providers!
            REQUEST_HEADERS_PROVIDERS.clear
          end
        end

        def initialize(llm_model)
          @llm_model = llm_model
        end

        def enforce_max_output_tokens(value)
          if @llm_model.max_output_tokens.to_i > 0
            value = @llm_model.max_output_tokens if (value.to_i > @llm_model.max_output_tokens) ||
              (value.to_i <= 0)
          end
          value
        end

        def use_ssl?
          if model_uri&.scheme.present?
            model_uri.scheme == "https"
          else
            true
          end
        end

        def xml_tags_to_strip(dialect)
          []
        end

        def perform_completion!(
          dialect,
          user,
          model_params = {},
          feature_name: nil,
          feature_context: nil,
          partial_tool_calls: false,
          output_thinking: false,
          cancel_manager: nil,
          execution_context: nil,
          &blk
        )
          LlmQuota.check_quotas!(@llm_model, user)
          LlmCreditAllocation.check_credits!(@llm_model, feature_name)

          if cancel_manager && cancel_manager.cancelled?
            # nothing to do
            return
          end

          @forced_json_through_prefill = false
          @partial_tool_calls = partial_tool_calls
          @output_thinking = output_thinking
          @feature_name = feature_name
          @feature_context = feature_context

          max_tokens = enforce_max_output_tokens(model_params[:max_tokens])
          model_params[:max_tokens] = max_tokens if max_tokens
          model_params = normalize_model_params(model_params)

          if block_given? && disable_streaming?
            return(
              replay_non_streaming_as_streaming!(
                dialect,
                user,
                model_params,
                feature_name: feature_name,
                feature_context: feature_context,
                partial_tool_calls: partial_tool_calls,
                output_thinking: output_thinking,
                cancel_manager: cancel_manager,
                execution_context: execution_context,
                &blk
              )
            )
          end

          @streaming_mode = block_given?

          prompt = dialect.translate
          @request_has_images = prompt_has_images?(prompt)
          perform_completion_request_with_retries(
            prompt: prompt,
            dialect: dialect,
            user: user,
            model_params: model_params,
            feature_name: feature_name,
            feature_context: feature_context,
            partial_tool_calls: partial_tool_calls,
            orig_blk: blk,
            cancel_manager: cancel_manager,
            execution_context: execution_context,
          )
        end

        def replay_non_streaming_as_streaming!(
          dialect,
          user,
          model_params,
          feature_name:,
          feature_context:,
          partial_tool_calls:,
          output_thinking:,
          cancel_manager:,
          execution_context:,
          &blk
        )
          result =
            perform_completion!(
              dialect,
              user,
              model_params,
              feature_name: feature_name,
              feature_context: feature_context,
              partial_tool_calls: partial_tool_calls,
              output_thinking: output_thinking,
              cancel_manager: cancel_manager,
              execution_context: execution_context,
            )

          wrapped = result
          wrapped = [result] if !result.is_a?(Array)
          wrapped.each do |partial|
            blk.call(partial)
            break if cancel_manager&.cancelled?
          end
          result
        end

        def build_structured_output(model_params)
          return if model_params[:response_format].blank?

          schema_properties = model_params[:response_format].dig(:json_schema, :schema, :properties)
          return if schema_properties.blank?

          DiscourseAi::Completions::StructuredOutput.new(schema_properties)
        end

        def perform_completion_request_with_retries(
          prompt:,
          dialect:,
          user:,
          model_params:,
          feature_name:,
          feature_context:,
          partial_tool_calls:,
          orig_blk:,
          cancel_manager:,
          execution_context:
        )
          request_started_at = Time.now
          cancelled = false
          call_status = :error
          retry_count_429 = 0
          # 408/409/5xx and network errors share one transient budget.
          retry_count_transient = 0
          request_attempts = []
          retried = false
          next_attempt_delay_ms = 0
          @forced_json_through_prefill = false
          request_body = prepare_payload(prompt, model_params, dialect).to_json
          log =
            start_completion_log(
              request_body: request_body,
              dialect: dialect,
              prompt: prompt,
              user: user,
              feature_name: feature_name,
              feature_context: feature_context,
            )

          loop do
            call_status = :error
            response_data = +""
            response_raw = +""

            # Needed to response token calculations. Cannot rely on response_data due to function buffering.
            partials_raw = +""
            structured_output = build_structured_output(model_params)

            request = prepare_request(request_body)
            retrying = false
            retry_delay = nil
            retry_status = nil
            current_attempt_delay_ms = next_attempt_delay_ms
            next_attempt_delay_ms = 0
            response_output_started = false
            cancel_manager_callback = nil

            if cancelled || cancel_manager&.cancelled?
              call_status = :cancelled
              break
            end

            begin
              FinalDestination::HTTP.start(
                model_uri.host,
                model_uri.port,
                use_ssl: use_ssl?,
                read_timeout: TIMEOUT,
                open_timeout: TIMEOUT,
                write_timeout: TIMEOUT,
              ) do |http|
                if cancel_manager
                  cancel_manager_callback =
                    lambda do
                      cancelled = true
                      call_status = :cancelled
                      http.finish
                    end
                  cancel_manager.add_callback(cancel_manager_callback)
                end

                begin
                  http.request(request) do |response|
                    log.response_status = response.code.to_i if log

                    if response.code.to_i != 200
                      retry_status, retry_delay =
                        failed_response_retry_status_and_delay(
                          response,
                          response_raw,
                          retry_count_429: retry_count_429,
                          retry_count_transient: retry_count_transient,
                        )
                      retrying = !retry_delay.nil?
                      raise CompletionFailed, response.body
                    end

                    # Some providers rely on prefill to return structured outputs, so the start
                    # of the JSON won't be included in the response. Supply it to keep JSON valid.
                    structured_output << +"{" if structured_output && @forced_json_through_prefill

                    xml_tool_processor = build_xml_tool_processor(dialect, partial_tool_calls)
                    xml_stripper = build_xml_stripper(dialect)

                    if @streaming_mode
                      blk = streaming_partial_handler(orig_blk, xml_stripper, structured_output)
                    end

                    if !@streaming_mode
                      response_data =
                        non_streaming_response(
                          response: response,
                          xml_tool_processor: xml_tool_processor,
                          xml_stripper: xml_stripper,
                          partials_raw: partials_raw,
                          response_raw: response_raw,
                          structured_output: structured_output,
                        )
                      call_status = :success
                      return response_data
                    end

                    response_data =
                      streaming_response(
                        response: response,
                        blk: blk,
                        xml_tool_processor: xml_tool_processor,
                        xml_stripper: xml_stripper,
                        partials_raw: partials_raw,
                        response_raw: response_raw,
                        structured_output: structured_output,
                        cancelled: -> { cancelled },
                        on_output_started: -> { response_output_started = true },
                      )
                    call_status = :success
                    return response_data
                  end
                rescue *RETRIABLE_NETWORK_ERRORS => e
                  raise if cancelled

                  Rails.logger.warn(
                    "#{self.class.name}: retryable network error: #{e.class}: #{e.message}",
                  )
                  if response_output_started
                    retrying = false
                    raise CompletionFailed, e.message
                  end

                  retry_status = NETWORK_ERROR_RETRY_STATUS
                  retry_delay =
                    retry_delay_for_network_error(retry_count_transient: retry_count_transient)
                  retrying = !retry_delay.nil?
                  raise CompletionFailed, e.message
                ensure
                  if cancel_manager && cancel_manager_callback
                    cancel_manager.remove_callback(cancel_manager_callback)
                  end
                end
              end
            rescue *RETRIABLE_NETWORK_ERRORS => e
              raise if cancelled

              Rails.logger.warn(
                "#{self.class.name}: retryable network error: #{e.class}: #{e.message}",
              )
              retry_status = NETWORK_ERROR_RETRY_STATUS
              retry_delay =
                retry_delay_for_network_error(retry_count_transient: retry_count_transient)
              retrying = !retry_delay.nil?

              if retrying
                request_attempts << request_attempt(retry_status, current_attempt_delay_ms)
                retried = true
                next_attempt_delay_ms = retry_delay_to_ms(retry_delay)
                retry_count_transient += 1
                sleep_before_retry(retry_delay, cancel_manager) if retry_delay.positive?
                next
              end

              raise CompletionFailed, e.message
            rescue CompletionFailed
              if retrying && !cancelled
                if retry_status
                  request_attempts << request_attempt(retry_status, current_attempt_delay_ms)
                  retried = true
                  next_attempt_delay_ms = retry_delay_to_ms(retry_delay)
                end

                if retry_status == 429
                  retry_count_429 += 1
                else
                  retry_count_transient += 1
                end

                sleep_before_retry(retry_delay, cancel_manager) if retry_delay.positive?
                next
              end

              raise
            ensure
              should_log = log && call_status != :cancelled && !retrying

              if should_log
                if retried
                  final_attempt_status = retry_status || log.response_status
                  if final_attempt_status
                    request_attempts << request_attempt(
                      final_attempt_status,
                      current_attempt_delay_ms,
                    )
                  end
                end

                persist_completion_log!(
                  log,
                  response_raw: response_raw,
                  partials_raw: partials_raw,
                  request_attempts: request_attempts.presence,
                  call_status: call_status,
                  start_time: request_started_at,
                  feature_name: feature_name,
                  user: user,
                  execution_context: execution_context,
                )
              end

              track_failures(call_status) if !retrying

              if should_log
                log_completion_audit_entries(
                  log,
                  request: request,
                  response_data: response_data,
                  start_time: request_started_at,
                  execution_context: execution_context,
                )
              end
            end
          end
        rescue IOError, StandardError
          raise if !cancelled
        end

        private :replay_non_streaming_as_streaming!,
                :build_structured_output,
                :perform_completion_request_with_retries

        def final_log_update(log)
          # for people that need to override
        end

        def default_options
          raise NotImplementedError
        end

        def provider_id
          raise NotImplementedError
        end

        def prompt_size(prompt)
          tokenizer.size(extract_prompt_for_tokenizer(prompt))
        end

        attr_reader :llm_model

        # Extra HTTP headers contributed by registered providers for this
        # request. Endpoints that want them merge the result into their request
        # headers. Provider failures are isolated so they can never break a
        # completion.
        def extra_request_headers
          providers = self.class.request_headers_providers
          return {} if providers.blank?

          context =
            RequestHeaderContext.new(
              llm_model: llm_model,
              feature_name: @feature_name,
              feature_context: @feature_context,
              has_images: @request_has_images,
              streaming: @streaming_mode,
            )

          providers.each_with_object({}) do |provider, headers|
            result = provider.call(context)
            headers.merge!(result.stringify_keys) if result.is_a?(Hash)
          rescue StandardError => e
            Discourse.warn_exception(
              e,
              message: "Discourse AI request header provider raised an error; skipping it",
            )
          end
        end

        protected

        def tokenizer
          llm_model.tokenizer_class
        end

        # Detects whether the translated prompt carries image content, so
        # providers can flag vision requests. Mirrors the OpenAI-compatible
        # shape (messages with an array content holding "image_url" parts) used
        # by the providers that consume this; degrades to false otherwise.
        def prompt_has_images?(translated_prompt)
          return false if !translated_prompt.is_a?(Array)

          translated_prompt.any? do |message|
            content = message[:content] if message.is_a?(Hash)
            content.is_a?(Array) &&
              content.any? { |part| part.is_a?(Hash) && part[:type] == "image_url" }
          end
        rescue StandardError
          false
        end

        # should normalize temperature, max_tokens, stop_words to endpoint specific values
        def normalize_model_params(model_params)
          raise NotImplementedError
        end

        def model_uri
          raise NotImplementedError
        end

        def prepare_payload(_prompt, _model_params)
          raise NotImplementedError
        end

        def prepare_request(_payload)
          raise NotImplementedError
        end

        def decode(_response_raw)
          raise NotImplementedError
        end

        def decode_chunk_finish
          []
        end

        def decode_chunk(_chunk)
          raise NotImplementedError
        end

        def extract_prompt_for_tokenizer(prompt)
          prompt.map { |message| message[:content] || message["content"] || "" }.join("\n")
        end

        def xml_tools_enabled?
          raise NotImplementedError
        end

        def disable_streaming?
          @disable_streaming = !!llm_model.lookup_custom_param("disable_streaming")
        end

        private

        def start_completion_log(
          request_body:,
          dialect:,
          prompt:,
          user:,
          feature_name:,
          feature_context:
        )
          start_log(
            provider_id: provider_id,
            request_body: request_body,
            dialect: dialect,
            prompt: prompt,
            user: user,
            feature_name: feature_name,
            feature_context: feature_context,
          )
        end

        # Populated only once retrying occurs. Each entry represents an issued request in
        # the retried sequence, and delay_ms is the planned wait before that request.
        def request_attempt(status, delay_ms)
          { "status" => status, "delay_ms" => delay_ms }
        end

        def retry_delay_to_ms(retry_delay)
          (retry_delay.to_f * 1000).round
        end

        def failed_response_retry_status_and_delay(
          response,
          response_raw,
          retry_count_429:,
          retry_count_transient:
        )
          status = response.code.to_i
          retry_delay =
            retry_delay_for_response(
              response,
              retry_count_429: retry_count_429,
              retry_count_transient: retry_count_transient,
            )

          log_method = retry_delay ? :warn : :error
          Rails.logger.public_send(
            log_method,
            "#{self.class.name}: status: #{status} - body: #{response.body}",
          )
          response_raw << response.body.to_s

          [status, retry_delay]
        end

        def build_xml_tool_processor(dialect, partial_tool_calls)
          return if !xml_tools_enabled? || !dialect.prompt.has_tools?

          XmlToolProcessor.new(
            partial_tool_calls: partial_tool_calls,
            tool_definitions: dialect.prompt.tools,
          )
        end

        def build_xml_stripper(dialect)
          to_strip = xml_tags_to_strip(dialect)
          return if to_strip.blank?

          DiscourseAi::Completions::XmlTagStripper.new(to_strip)
        end

        def streaming_partial_handler(orig_blk, xml_stripper, structured_output)
          lambda do |partial|
            if partial.is_a?(String)
              partial = xml_stripper << partial if xml_stripper && !partial.empty?

              if structured_output.present?
                structured_output << partial if !partial.empty?
                partial = structured_output
              end
            end
            orig_blk.call(partial) if partial
          end
        end

        def streaming_response(
          response:,
          blk:,
          xml_tool_processor:,
          xml_stripper:,
          partials_raw:,
          response_raw:,
          structured_output:,
          cancelled:,
          on_output_started:
        )
          response_data = +""

          response.read_body do |chunk|
            break if cancelled.call

            response_raw << chunk

            decode_chunk(chunk).each do |partial|
              break if cancelled.call
              partials_raw << partial.to_s
              response_data << partial if partial.is_a?(String)
              partials = [partial]
              if xml_tool_processor && partial.is_a?(String)
                partials = (xml_tool_processor << partial)
                break if xml_tool_processor.should_cancel?
              end
              partials.each do |inner_partial|
                on_output_started.call
                blk.call(inner_partial)
              end
            end
          end

          finish_streaming_response(
            response_data: response_data,
            blk: blk,
            xml_tool_processor: xml_tool_processor,
            xml_stripper: xml_stripper,
            structured_output: structured_output,
          )

          response_data
        end

        def finish_streaming_response(
          response_data:,
          blk:,
          xml_tool_processor:,
          xml_stripper:,
          structured_output:
        )
          if xml_stripper
            stripped = xml_stripper.finish
            if stripped.present?
              response_data << stripped
              result = []
              result = (xml_tool_processor << stripped) if xml_tool_processor
              result.each { |partial| blk.call(partial) }
            end
          end

          xml_tool_processor.finish.each { |partial| blk.call(partial) } if xml_tool_processor
          decode_chunk_finish.each { |partial| blk.call(partial) }

          finish_structured_output_streaming(structured_output, blk) if structured_output
        end

        def finish_structured_output_streaming(structured_output, blk)
          structured_output.finish
          if structured_output.broken?
            # signal last partial output which will get parsed
            # by best effort json parser
            blk.call("")
          else
            # got to signal the end of structured output
            blk.call(structured_output)
          end
        end

        def persist_completion_log!(
          log,
          response_raw:,
          partials_raw:,
          request_attempts:,
          call_status:,
          start_time:,
          feature_name:,
          user:,
          execution_context:
        )
          log.raw_response_payload = response_raw
          log.request_attempts = request_attempts if log.has_attribute?(:request_attempts)
          final_log_update(log)
          log.response_tokens = tokenizer.size(partials_raw) if log.response_tokens.blank?
          log.response_status ||= 200 if call_status == :success
          log.created_at = start_time
          log.updated_at = Time.now
          log.duration_msecs = (Time.now - start_time) * 1000
          log.save!

          execution_context&.token_usage_tracker&.add_from_audit_log(log)

          AiApiRequestStat.record_from_audit_log(log, llm_model: @llm_model)
          LlmQuota.log_usage(@llm_model, user, log.request_tokens, log.response_tokens)
          LlmCreditAllocation.deduct_credits!(
            @llm_model,
            feature_name,
            log.request_tokens,
            log.response_tokens,
          )

          DiscourseAi::Completions::LlmMetric.record(
            llm_model: @llm_model,
            feature_name: feature_name,
            request_tokens: log.request_tokens || 0,
            response_tokens: log.response_tokens || 0,
            duration_ms: log.duration_msecs,
            status: call_status,
          )

          if Rails.env.development? && ENV["DISCOURSE_AI_DEBUG"]
            puts "#{self.class.name}: request_tokens #{log.request_tokens} response_tokens #{log.response_tokens}"
          end
        end

        def log_completion_audit_entries(
          log,
          request:,
          response_data:,
          start_time:,
          execution_context:
        )
          log_text_audit_entry(log, response_data, execution_context&.audit_logger)
          log_structured_audit_entry(
            log,
            request: request,
            response_data: response_data,
            start_time: start_time,
            structured_logger: execution_context&.structured_audit_logger,
          )
        end

        def log_text_audit_entry(log, response_data, logger)
          return if !logger

          call_data = <<~LOG
            #{self.class.name}: request_tokens #{log.request_tokens} response_tokens #{log.response_tokens}
            request:
            #{format_possible_json_payload(log.raw_request_payload)}
            response:
            #{response_data}
          LOG
          logger.info(call_data)
        end

        def log_structured_audit_entry(
          log,
          request:,
          response_data:,
          start_time:,
          structured_logger:
        )
          return if !structured_logger

          llm_request =
            begin
              JSON.parse(log.raw_request_payload)
            rescue StandardError
              log.raw_request_payload
            end

          # gemini puts passwords in query params
          # we don't want to log that
          llm_call_step = structured_logger.add_child_step(name: "Performing LLM call")

          structured_logger.append_entry(
            step: llm_call_step,
            name: "llm_call",
            args: {
              class: self.class.name,
              completion_url: request.uri.to_s.split("?")[0],
              request: llm_request,
              result: response_data,
              request_tokens: log.request_tokens,
              response_tokens: log.response_tokens,
              duration: log.duration_msecs,
              stream: @streaming_mode,
            },
            started_at: start_time.utc,
            ended_at: Time.now.utc,
          )
        end

        def retry_delay_for_response(response, retry_count_429:, retry_count_transient:)
          status = response.code.to_i

          if status == 429 && retry_count_429 < RATE_LIMIT_RETRY_DELAYS.length
            delay = RATE_LIMIT_RETRY_DELAYS[retry_count_429]
            retry_after_delay = [
              retry_after_delay(response["Retry-After"]),
              retry_delay_from_response_body(response.body),
            ].compact.max

            return [delay, retry_after_delay].compact.max + retry_jitter
          end

          if transient_error_status?(status) &&
               retry_count_transient < TRANSIENT_ERROR_RETRY_DELAYS.length
            delay = TRANSIENT_ERROR_RETRY_DELAYS[retry_count_transient]
            retry_after_delay = [
              retry_after_delay(response["Retry-After"]),
              retry_delay_from_response_body(response.body),
            ].compact.max

            return [delay, retry_after_delay].compact.max + retry_jitter
          end

          nil
        end

        def retry_delay_for_network_error(retry_count_transient:)
          return if retry_count_transient >= TRANSIENT_ERROR_RETRY_DELAYS.length

          TRANSIENT_ERROR_RETRY_DELAYS[retry_count_transient] + retry_jitter
        end

        def transient_error_status?(status)
          status == 408 || status == 409 || (status >= 500 && status < 600)
        end

        def sleep_before_retry(delay, cancel_manager = nil)
          if cancel_manager
            cancel_manager.wait_for_cancel(delay) if !cancel_manager.cancelled?
          else
            sleep(delay)
          end
        end

        def retry_after_delay(header)
          return if header.blank?

          delay =
            if header.to_s.match?(/\A\d+(\.\d+)?\z/)
              header.to_f
            else
              Time.httpdate(header).to_f - Time.now.to_f
            end

          return if delay <= 0

          [delay, MAX_RETRY_AFTER_SECONDS].min
        rescue StandardError
          nil
        end

        def retry_delay_from_response_body(_body)
          nil
        end

        def retry_jitter
          rand * RETRY_JITTER_MAX_SECONDS
        end

        def format_possible_json_payload(payload)
          JSON.pretty_generate(JSON.parse(payload))
        rescue JSON::ParserError
          payload
        end

        def track_failures(call_status)
          return if call_status == :cancelled
          return if llm_model.blank? || llm_model.seeded? || llm_model.new_record?
          key = "ai_llm_status_fast_fail:#{llm_model.id}"

          if call_status == :success
            Discourse.redis.del(key)
            return
          end

          failures_count = Discourse.redis.incr(key)
          Discourse.redis.expire(key, FAIL_TTL.to_i)

          return if failures_count < FAIL_THRESHOLD

          ProblemCheck::AiLlmStatus.fast_track_problem!(
            llm_model,
            failures_count,
            FAIL_TTL / 1.hour,
          )
        end

        def start_log(
          provider_id:,
          request_body:,
          dialect:,
          prompt:,
          user:,
          feature_name:,
          feature_context:
        )
          AiApiAuditLog.new(
            provider_id: provider_id,
            user_id: user&.id,
            raw_request_payload: request_body,
            request_tokens: prompt_size(prompt),
            topic_id: dialect.prompt.topic_id,
            post_id: dialect.prompt.post_id,
            feature_name: feature_name,
            llm_id: llm_model&.id,
            language_model: llm_model.name,
            feature_context: feature_context.presence&.as_json,
          )
        end

        def non_streaming_response(
          response:,
          xml_tool_processor:,
          xml_stripper:,
          partials_raw:,
          response_raw:,
          structured_output:
        )
          response_raw << response.read_body
          response_data = decode(response_raw)

          response_data.each { |partial| partials_raw << partial.to_s }

          if xml_tool_processor
            response_data.each do |partial|
              processed = (xml_tool_processor << partial)
              processed << xml_tool_processor.finish
              response_data = []
              processed.flatten.compact.each { |inner| response_data << inner }
            end
          end

          if xml_stripper
            response_data.map! do |partial|
              stripped = (xml_stripper << partial) if partial.is_a?(String)
              stripped.presence || partial
            end
            response_data << xml_stripper.finish
          end

          response_data.reject!(&:blank?)

          if structured_output.present?
            response_data.each { |data| structured_output << data if data.is_a?(String) }
            structured_output.finish

            return structured_output
          end

          # this is to keep stuff backwards compatible
          response_data = response_data.first if response_data.length == 1
          response_data = "" if response_data.nil?

          response_data
        end
      end
    end
  end
end

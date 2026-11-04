# frozen_string_literal: true

module DiscourseAi
  module Decisions
    class Client
      # Billing a provider that omits usage must not make its decisions free. Engines
      # answer every question in a single pass over the state, behind a fixed prompt.
      ESTIMATED_PROMPT_TOKENS = 85
      ESTIMATED_TOKENS_PER_IMAGE = 1_000

      def initialize(decision_model, timeout: 30, max_attempts: 3)
        @decision_model = decision_model
        @endpoint = Endpoints::Base.for(decision_model)
        @timeout = timeout
        @max_attempts = max_attempts
      end

      def decide(state, questions:, feature_name:, user: nil, images: [])
        questions = Array.wrap(questions).map { |question| Question.wrap(question) }
        validate!(state, questions, feature_name, images)
        DecisionModelCreditAllocation.check_credits!(@decision_model, feature_name)
        if (canned = CannedAnswers.current)
          return canned.decide(state:, questions:, feature_name:, user:, images:)
        end

        uri = URI(@decision_model.endpoint_url)
        payload = @endpoint.payload(state:, questions:, images:)
        body = payload.to_json
        log =
          AiApiAuditLog.new(
            provider_id: @endpoint.provider_id,
            user_id: user&.id,
            feature_name:,
            language_model: @decision_model.name,
            raw_request_payload: @endpoint.audit_payload(payload).to_json,
          )
        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        begin
          headers = @endpoint.headers(feature_name:, has_images: images.present?)
          response_body = post(uri, headers, body, log)
          begin
            parsed = JSON.parse(response_body)
            # Cloudflare Workers AI wraps answers in {result, success, errors}.
            parsed = parsed["result"] if parsed.is_a?(Hash) && parsed["success"] == true
          rescue JSON::ParserError
            raise RequestFailed.new(
                    "Request failed: invalid JSON",
                    http_status: log.response_status,
                  )
          end
          answers = @endpoint.parse(parsed, questions)
          input_tokens, output_tokens = @endpoint.usage(parsed)
          log.request_tokens = input_tokens
          log.response_tokens = output_tokens
        ensure
          log.duration_msecs =
            ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round
          log.save!
          AiApiRequestStat.record_from_audit_log(log, llm_model: nil)
        end
        if @decision_model.credit_system_enabled?
          input_tokens_for_credits =
            input_tokens || estimated_input_tokens(state, questions, images)
          DecisionModelCreditAllocation.deduct_credits!(
            @decision_model,
            feature_name,
            input_tokens_for_credits + output_tokens.to_i,
          )
        end
        Result.new(
          answers:,
          provider_model: parsed["model"],
          input_tokens:,
          output_tokens:,
          audit_log_id: log.id,
        )
      end

      private

      def estimated_input_tokens(state, questions, images)
        tokenizer = DiscourseAi::Tokenizer::OpenAiTokenizer
        question_tokens =
          questions.sum do |question|
            criteria = [*question.choices, *question.levels].join(" ")
            tokenizer.size("#{question.instructions} #{criteria}")
          end
        tokenizer.size(state.is_a?(String) ? state : state.to_json) +
          images.size * ESTIMATED_TOKENS_PER_IMAGE + question_tokens + ESTIMATED_PROMPT_TOKENS
      end

      def validate!(state, questions, feature_name, images)
        raise InvalidRequest, "feature_name is required" if feature_name.blank?
        raise InvalidRequest, "At least one question is required" if questions.empty?
        if questions.map(&:name).uniq.size != questions.size
          raise InvalidRequest, "Question names must be unique"
        end
        raise InvalidRequest, "Images must be a list of base64 data URLs" if !images.is_a?(Array)
        if images.any? { |image|
             !image.is_a?(String) || !image.start_with?("data:image/") ||
               !image.include?(";base64,")
           }
          raise InvalidRequest, "Images must be base64 data URLs"
        end
        if images.present? && !@decision_model.vision_enabled
          raise InvalidRequest, "Images require a decision model with image input enabled"
        end
        raise InvalidRequest, "State must be present" if state.blank?
        if !state.is_a?(String) && !state.is_a?(Hash) && !state.is_a?(Array)
          raise InvalidRequest, "State must be a string, hash or array"
        end
      end

      def retryable_network_error?(exception)
        return false if exception.is_a?(FinalDestination::SSRFError)
        # FinalDestination raises a bare Timeout::Error when DNS resolution is slow.
        return true if exception.is_a?(Timeout::Error)

        DiscourseAi::Completions::Endpoints::Base::RETRIABLE_NETWORK_ERRORS.any? do |klass|
          exception.is_a?(klass)
        end
      end

      # @return [String] the body of the successful response; the audit log only keeps a
      #   redacted copy
      def post(uri, headers, body, log)
        api_key = @decision_model.api_key
        header_values = @decision_model.custom_headers_for_request.values
        attempts = []
        loop do
          begin
            request = FinalDestination::HTTP::Post.new(uri.request_uri, headers)
            request.body = body
            response =
              FinalDestination::HTTP.start(
                uri.host,
                uri.port,
                use_ssl: uri.scheme == "https",
                open_timeout: @timeout,
                read_timeout: @timeout,
                write_timeout: @timeout,
              ) { |http| http.request(request) }
            log.response_status = response.code.to_i
            log.raw_response_payload =
              RequestFailed.redact_response(response.body, api_key, header_values:)
            error = RequestFailed.from_response(@decision_model, response) if !response.is_a?(
              Net::HTTPSuccess,
            )
          rescue StandardError => exception
            log.response_status = 0
            message = RequestFailed.sanitize(exception.message, api_key, header_values:)
            error =
              RequestFailed.new(
                "Request failed: #{message}",
                retryable: retryable_network_error?(exception),
              )
          end
          return response.body.to_s if error.nil?
          raise error if !error.retryable? || attempts.size + 1 >= @max_attempts

          delay = (error.retry_after || 2**attempts.size).clamp(0, 5)
          attempts << { "status" => error.http_status || 0, "delay_ms" => (delay * 1000).round }
          log.request_attempts = attempts
          sleep(delay)
        end
      end
    end
  end
end

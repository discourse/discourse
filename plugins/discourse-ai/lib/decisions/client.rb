# frozen_string_literal: true

module DiscourseAi
  module Decisions
    # Most callers should use DecisionModel#decide; build a client directly to
    # tune the timeout or retries.
    class Client
      DEFAULT_TIMEOUT = 30
      DEFAULT_MAX_ATTEMPTS = 3
      MAX_RETRY_DELAY = 5
      # Stored in AiApiAuditLog#request_attempts for network failures, which have no HTTP status.
      NETWORK_ERROR_STATUS = 0
      REDACTED_IMAGE = "[image]"

      def initialize(decision_model, timeout: DEFAULT_TIMEOUT, max_attempts: DEFAULT_MAX_ATTEMPTS)
        @decision_model = decision_model
        @endpoint = Endpoints::Base.for(decision_model)
        @timeout = timeout
        @max_attempts = max_attempts
      end

      # @param state [String, Hash, Array] the content to evaluate
      # @param questions [Array<Hash, Question>] see Question for the hash format
      # @param feature_name [String] attributes usage in the audit log
      # @param images [Array<String>] base64 data URLs; requires a vision-enabled model
      # @return [Result]
      # @raise [InvalidQuestion, InvalidRequest, InferenceError]
      def decide(state, questions:, feature_name:, user: nil, images: [], feature_context: nil)
        questions = Array.wrap(questions).map { |question| Question.wrap(question) }
        validate!(state, questions, images, feature_name)

        if (canned = CannedAnswers.current)
          return(canned.decide(state:, questions:, images:, user:, feature_name:, feature_context:))
        end

        body = @endpoint.payload(state:, questions:, images:).to_json
        log =
          AiApiAuditLog.new(
            provider_id: @endpoint.provider_id,
            user_id: user&.id,
            feature_name: feature_name,
            feature_context: feature_context.presence&.as_json,
            language_model: @decision_model.name,
            raw_request_payload: redact_images(body, images),
          )
        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        begin
          response = post(body, log)
          log.response_status = response.status
          log.raw_response_payload = response.body.to_s

          raise InferenceError.from_response(response) if response.status != 200

          parsed = @endpoint.parse(parse_body(response.body), questions)
          log.request_tokens = parsed[:input_tokens]
          log.response_tokens = parsed[:output_tokens]
        ensure
          log.duration_msecs =
            ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round
          log.save!
          AiApiRequestStat.record_from_audit_log(log, llm_model: nil)
        end

        Result.new(**parsed, audit_log_id: log.id)
      end

      private

      def validate!(state, questions, images, feature_name)
        raise InvalidRequest, "feature_name is required" if feature_name.blank?
        raise InvalidRequest, "State can't be blank" if state.blank?
        raise InvalidRequest, "At least one question is required" if questions.empty?

        if questions.map(&:name).uniq.size != questions.size
          raise InvalidRequest, "Question names must be unique"
        end

        return if images.blank?

        if !@decision_model.vision_enabled
          raise InvalidRequest, "#{@decision_model.display_name} doesn't support images"
        end
        if images.any? { |image| !image.to_s.start_with?("data:image/") }
          raise InvalidRequest, "Images must be base64 data URLs"
        end
      end

      # Returns the last response, or raises when the last attempt never got one.
      def post(body, log)
        connection =
          Faraday.new(request: { timeout: @timeout, open_timeout: @timeout }) do |f|
            f.adapter FinalDestination::FaradayAdapter
          end
        attempts = []

        loop do
          begin
            response = connection.post(@decision_model.endpoint_url, body, @endpoint.headers)
            error = response.status == 200 ? nil : InferenceError.from_response(response)
          rescue Faraday::ConnectionFailed, Faraday::TimeoutError => e
            response = nil
            error = InferenceError.new("Decision model request failed: #{e.message}")
          end

          if error.nil? || !error.retryable? || attempts.size + 1 >= @max_attempts
            log.request_attempts = attempts.presence
            raise error if response.nil?
            return response
          end

          delay = (error.retry_after || 2**attempts.size).clamp(0, MAX_RETRY_DELAY)
          attempts << {
            "status" => error.http_status || NETWORK_ERROR_STATUS,
            "delay_ms" => delay * 1000,
          }
          sleep(delay)
        end
      end

      def parse_body(body)
        JSON.parse(body)
      rescue JSON::ParserError
        raise InferenceError.new("Decision model returned invalid JSON", http_status: 200)
      end

      # Images would bloat the audit log, so they're stored as placeholders.
      def redact_images(body, images)
        images.reduce(body) { |redacted, image| redacted.gsub(image, REDACTED_IMAGE) }
      end
    end
  end
end

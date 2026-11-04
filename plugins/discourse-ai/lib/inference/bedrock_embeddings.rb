# frozen_string_literal: true

module DiscourseAi
  module Inference
    class BedrockEmbeddings
      TIMEOUT = 60

      CATEGORIES_BY_ERROR_CODE = {
        "AccessDeniedException" => :authorization_failed,
        "UnrecognizedClientException" => :authentication_failed,
        "ExpiredTokenException" => :authentication_failed,
        "ResourceNotFoundException" => :invalid_configuration,
        "ThrottlingException" => :rate_limited,
        "ServiceQuotaExceededException" => :rate_limited,
        "ServiceUnavailableException" => :provider_unavailable,
        "InternalServerException" => :provider_unavailable,
        "ModelNotReadyException" => :provider_unavailable,
        "ModelTimeoutException" => :provider_unavailable,
      }.freeze

      @role_credentials = {}
      @role_credentials_mutex = Mutex.new

      class << self
        # AssumeRoleCredentials calls STS when built and refreshes itself before
        # expiry, so share one per role instead of assuming it on every request.
        def role_credentials(role_arn, region)
          @role_credentials_mutex.synchronize do
            @role_credentials[[role_arn, region]] ||= begin
              require "aws-sdk-sts" unless defined?(Aws::STS)

              Aws::AssumeRoleCredentials.new(
                role_arn: role_arn,
                role_session_name: "discourse-bedrock-embeddings-#{Process.pid}",
                client: Aws::STS::Client.new(region: region),
              )
            end
          end
        end

        def reset_role_credentials!
          @role_credentials_mutex.synchronize { @role_credentials.clear }
        end
      end

      # Authentication is resolved in this order: an IAM role to assume, a static
      # access key pair (`api_key` holds the secret access key), a Bedrock API key
      # sent as a bearer token, then the AWS SDK default chain (environment,
      # shared config, instance or task role).
      def initialize(
        region:,
        model_id:,
        dimensions: nil,
        api_key: nil,
        access_key_id: nil,
        role_arn: nil
      )
        @region = region
        @model_id = model_id
        @dimensions = dimensions
        @api_key = api_key
        @access_key_id = access_key_id
        @role_arn = role_arn
      end

      attr_reader :region, :model_id, :dimensions

      def perform!(content)
        response =
          client.invoke_model(
            model_id: model_id,
            body: payload_for(content).to_json,
            content_type: "application/json",
            accept: "application/json",
          )

        extract_embedding(JSON.parse(response.body.read))
      rescue Aws::Errors::ServiceError => e
        raise error_from_service(e)
      rescue Aws::Errors::MissingCredentialsError, Aws::Sigv4::Errors::MissingCredentialsError => e
        raise EmbeddingInferenceError.new(
                provider: EmbeddingDefinition::AWS_BEDROCK,
                category: :authentication_failed,
                message: e.message,
              )
      rescue Seahorse::Client::NetworkingError => e
        raise EmbeddingInferenceError.new(
                provider: EmbeddingDefinition::AWS_BEDROCK,
                category: :provider_unavailable,
                message: e.message,
              )
      end

      private

      def model_family
        @model_family ||=
          if model_id.include?("cohere.embed")
            :cohere
          elsif model_id.include?("titan-embed-text")
            :titan
          else
            raise EmbeddingInferenceError.new(
                    provider: EmbeddingDefinition::AWS_BEDROCK,
                    category: :invalid_configuration,
                    message: "Unsupported Bedrock embedding model: #{model_id}",
                  )
          end
      end

      def payload_for(content)
        case model_family
        when :cohere
          payload = {
            texts: [content],
            input_type: "search_document",
            embedding_types: ["float"],
            truncate: "END",
          }
          payload[:output_dimension] = dimensions if dimensions.present?
          payload
        when :titan
          payload = { inputText: content, normalize: true }
          payload[:dimensions] = dimensions if dimensions.present?
          payload
        end
      end

      def extract_embedding(body)
        case model_family
        when :cohere
          body.dig("embeddings", "float", 0)
        when :titan
          body["embedding"]
        end
      end

      def client
        require "aws-sdk-bedrockruntime" unless defined?(Aws::BedrockRuntime)

        options = { region: region, http_read_timeout: TIMEOUT }

        if @role_arn.present?
          options[:credentials] = self.class.role_credentials(@role_arn, region)
        elsif @access_key_id.present?
          options[:credentials] = Aws::Credentials.new(@access_key_id, @api_key)
        elsif @api_key.present?
          # An explicit nil skips the default credential chain, whose instance
          # metadata probe stalls every request on hosts outside AWS.
          options[:credentials] = nil
          options[:token_provider] = Aws::StaticTokenProvider.new(@api_key)
          options[:auth_scheme_preference] = ["httpBearerAuth"]
        end

        Aws::BedrockRuntime::Client.new(options)
      end

      def error_from_service(error)
        status = error.context&.http_response&.status_code.to_i
        code = error.code.to_s

        EmbeddingInferenceError.new(
          provider: EmbeddingDefinition::AWS_BEDROCK,
          category: CATEGORIES_BY_ERROR_CODE[code] || category_for_status(status),
          http_status: status.nonzero?,
          provider_error_code: code,
          message: error.message,
        )
      end

      def category_for_status(status)
        return :authentication_failed if status == 401
        return :authorization_failed if status == 403
        return :rate_limited if status == 429
        return :provider_unavailable if status == 408 || status >= 500

        # Validation errors can be specific to one input, so they must not pause
        # the provider for every other request.
        :request_rejected
      end
    end
  end
end

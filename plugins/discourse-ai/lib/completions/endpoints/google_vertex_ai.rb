# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Endpoints
      class GoogleVertexAi < Gemini
        METADATA_TOKEN_URL =
          "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token"
        ADC_TOKEN_EXPIRY_BUFFER_SECONDS = 60
        ADC_TOKEN_MUTEX = Mutex.new

        class << self
          def can_contact?(llm_model)
            llm_model.provider == "google_vertex_ai"
          end

          def supports_environment_credentials?
            true
          end

          def requires_configured_url?
            false
          end

          def adc_token
            ADC_TOKEN_MUTEX.synchronize do
              return @adc_token if @adc_token && @adc_token_expires_at.after?(Time.zone.now)

              @adc_token = nil
              @adc_token_expires_at = nil

              payload = fetch_adc_token_payload
              token = payload&.dig("access_token")
              expires_in = payload&.dig("expires_in").to_i - ADC_TOKEN_EXPIRY_BUFFER_SECONDS

              if token.present? && expires_in > 0
                @adc_token = token
                @adc_token_expires_at = expires_in.seconds.from_now
              end

              @adc_token
            end
          end

          def reset_adc_token_cache!
            ADC_TOKEN_MUTEX.synchronize do
              @adc_token = nil
              @adc_token_expires_at = nil
            end
          end

          private

          def fetch_adc_token_payload
            uri = URI(METADATA_TOKEN_URL)
            request = Net::HTTP::Get.new(uri)
            request["Metadata-Flavor"] = "Google"

            response =
              Net::HTTP.start(uri.hostname, uri.port, read_timeout: 2, open_timeout: 2) do |http|
                http.request(request)
              end

            if response.is_a?(Net::HTTPSuccess)
              JSON.parse(response.body)
            else
              Rails.logger.warn(
                "DiscourseAi::GoogleVertexAi: ADC token request failed with status #{response.code}",
              )
              nil
            end
          rescue StandardError => e
            Rails.logger.warn(
              "DiscourseAi::GoogleVertexAi: Failed to fetch ADC token: #{e.message}",
            )
            nil
          end
        end

        def provider_id
          AiApiAuditLog::Provider::Gemini
        end

        private

        def model_uri
          project_id = llm_model.lookup_custom_param("project_id")
          region = llm_model.lookup_custom_param("region")
          model_name = vertex_model_name

          base_url =
            "#{vertex_api_base_url(region)}/v1/projects/#{project_id}/locations/#{region}/publishers/google/models/#{model_name}"

          url =
            if @streaming_mode
              "#{base_url}:streamGenerateContent?alt=sse"
            else
              "#{base_url}:generateContent"
            end

          URI(url)
        end

        def vertex_model_name
          llm_model.name.to_s.sub(%r{\Agoogle/}, "")
        end

        def vertex_api_base_url(region)
          return "https://aiplatform.googleapis.com" if region == "global"

          "https://#{region}-aiplatform.googleapis.com"
        end

        def prepare_request(payload)
          headers = {
            "Content-Type" => "application/json",
            "Authorization" => "Bearer #{access_token}",
          }

          Net::HTTP::Post.new(model_uri, headers).tap { |r| r.body = payload }
        end

        def access_token
          @access_token ||= llm_model.api_key.presence || self.class.adc_token
        end
      end
    end
  end
end

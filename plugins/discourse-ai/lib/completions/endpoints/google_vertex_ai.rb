# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Endpoints
      class GoogleVertexAi < Gemini
        def self.can_contact?(llm_model)
          llm_model.provider == "google_vertex_ai"
        end

        def self.supports_environment_credentials?
          true
        end

        def self.requires_configured_url?
          false
        end

        def provider_id
          AiApiAuditLog::Provider::Gemini # Keep using Gemini audit log provider
        end

        private

        def model_uri
          project_id = llm_model.lookup_custom_param("project_id")
          region = llm_model.lookup_custom_param("region")
          model_name = vertex_model_name

          base_url =
            "#{vertex_api_base_url(region)}/v1/projects/#{project_id}/locations/#{region}/publishers/google/models/#{model_name}"

          url = if @streaming_mode
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
          @access_token ||= fetch_adc_token || llm_model.api_key
        end

        def fetch_adc_token
          uri = URI(
            "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token",
          )
          req = Net::HTTP::Get.new(uri)
          req["Metadata-Flavor"] = "Google"

          response =
            Net::HTTP.start(uri.hostname, uri.port, read_timeout: 2, open_timeout: 2) do |http|
              http.request(req)
            end

          if response.is_a?(Net::HTTPSuccess)
            JSON.parse(response.body)["access_token"]
          else
            nil
          end
        rescue StandardError => e
          Rails.logger.error(
            "DiscourseAi::GoogleVertexAi: Failed to fetch ADC token: #{e.message}",
          )
          nil
        end
      end
    end
  end
end

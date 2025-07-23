# frozen_string_literal: true

module ::DiscourseAi
  module Inference
    class StabilityGenerator
      TIMEOUT = 120

      # there is a new api for sd3
      def self.perform_sd3!(
        prompt,
        aspect_ratio: nil,
        api_key: nil,
        engine: nil,
        api_url: nil,
        output_format: "png",
        seed: nil
      )
        api_key ||= SiteSetting.ai_stability_api_key
        engine ||= SiteSetting.ai_stability_engine
        api_url ||= SiteSetting.ai_stability_api_url

        allowed_ratios = %w[16:9 1:1 21:9 2:3 3:2 4:5 5:4 9:16 9:21]

        aspect_ratio = "1:1" if !aspect_ratio || !allowed_ratios.include?(aspect_ratio)

        payload = {
          prompt: prompt,
          mode: "text-to-image",
          model: engine,
          output_format: output_format,
          aspect_ratio: aspect_ratio,
        }

        payload[:seed] = seed if seed

        endpoint = "v2beta/stable-image/generate/sd3"

        form_data = payload.to_a.map { |k, v| [k.to_s, v.to_s] }

        uri = URI("#{api_url}/#{endpoint}")
        request = FinalDestination::HTTP::Post.new(uri)

        request["authorization"] = "Bearer #{api_key}"
        request["accept"] = "application/json"
        request["User-Agent"] = DiscourseAi::AiBot::USER_AGENT
        request.set_form form_data, "multipart/form-data"

        response =
          FinalDestination::HTTP.start(
            uri.hostname,
            uri.port,
            use_ssl: uri.port != 80,
            read_timeout: TIMEOUT,
            open_timeout: TIMEOUT,
            write_timeout: TIMEOUT,
          ) { |http| http.request(request) }

        if response.code != "200"
          Rails.logger.error(
            "AI stability generator failed with status #{response.code}: #{response.body}}",
          )
          raise Net::HTTPBadResponse
        end

        parsed = JSON.parse(response.body, symbolize_names: true)

        # remap to old format
        { artifacts: [{ base64: parsed[:image], seed: parsed[:seed] }] }
      end

      def self.perform!(
        prompt,
        aspect_ratio: nil,
        api_key: nil,
        engine: nil,
        api_url: nil,
        image_count: 4,
        seed: nil
      )
        api_key ||= SiteSetting.ai_stability_api_key
        engine ||= SiteSetting.ai_stability_engine
        api_url ||= SiteSetting.ai_stability_api_url

        image_count = 4 if image_count > 4

        if engine.start_with? "sd3"
          artifacts =
            image_count.times.map do
              perform_sd3!(
                prompt,
                api_key: api_key,
                engine: engine,
                api_url: api_url,
                aspect_ratio: aspect_ratio,
                seed: seed,
              )[
                :artifacts
              ][
                0
              ]
            end

          return { artifacts: artifacts }
        end

        headers = {
          "Content-Type" => "application/json",
          "Accept" => "application/json",
          "Authorization" => "Bearer #{api_key}",
        }

        ratio_to_dimension = {
          "16:9" => [1536, 640],
          "1:1" => [1024, 1024],
          "21:9" => [1344, 768],
          "2:3" => [896, 1152],
          "3:2" => [1152, 896],
          "4:5" => [832, 1216],
          "5:4" => [1216, 832],
          "9:16" => [640, 1536],
          "9:21" => [768, 1344],
        }

        if engine.include? "xl"
          width, height = ratio_to_dimension[aspect_ratio] if aspect_ratio

          width, height = [1024, 1024] if !width || !height
        else
          width, height = [512, 512]
        end

        payload = {
          text_prompts: [{ text: prompt }],
          cfg_scale: 7,
          clip_guidance_preset: "FAST_BLUE",
          height: width,
          width: height,
          samples: image_count,
          steps: 30,
        }

        payload[:seed] = seed if seed

        endpoint = "v1/generation/#{engine}/text-to-image"

        conn = Faraday.new { |f| f.adapter FinalDestination::FaradayAdapter }
        response = conn.post("#{api_url}/#{endpoint}", payload.to_json, headers)

        if response.status != 200
          Rails.logger.error(
            "AI stability generator failed with status #{response.status}: #{response.body}}",
          )
          raise Net::HTTPBadResponse
        end

        JSON.parse(response.body, symbolize_names: true)
      end
    end
  end
end

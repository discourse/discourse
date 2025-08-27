# frozen_string_literal: true

module ::DiscourseAi
  module Inference
    class DiscourseReranker
      def self.perform!(endpoint, model, content, candidates, api_key)
        headers = { "Referer" => Discourse.base_url, "Content-Type" => "application/json" }

        headers["X-API-KEY"] = api_key if api_key.present?

        conn = Faraday.new { |f| f.adapter FinalDestination::FaradayAdapter }
        response =
          conn.post(
            endpoint,
            { model: model, content: content, candidates: candidates }.to_json,
            headers,
          )

        raise Net::HTTPBadResponse unless response.status == 200

        JSON.parse(response.body, symbolize_names: true)
      end
    end
  end
end

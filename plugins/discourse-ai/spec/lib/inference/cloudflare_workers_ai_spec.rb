# frozen_string_literal: true

require "webmock/rspec"

RSpec.describe DiscourseAi::Inference::CloudflareWorkersAi do
  subject(:cloudflare_workers_ai) { described_class.new(endpoint, api_token) }

  let(:account_id) { "test_account_id" }
  let(:api_token) { "test_api_token" }
  let(:model) { "test_model" }
  let(:content) { "test content" }
  let(:endpoint) do
    "https://api.cloudflare.com/client/v4/accounts/#{account_id}/ai/run/@cf/#{model}"
  end
  let(:headers) do
    {
      "Referer" => Discourse.base_url,
      "Content-Type" => "application/json",
      "Authorization" => "Bearer #{api_token}",
    }
  end
  let(:payload) { { text: [content] }.to_json }

  before do
    enable_current_plugin

    stub_request(:post, endpoint).with(body: payload, headers: headers).to_return(
      status: response_status,
      body: response_body,
    )
  end

  describe "#perform!" do
    context "when the response status is 200" do
      let(:response_status) { 200 }
      let(:response_body) { { result: { data: ["embedding_result"] } }.to_json }

      it "returns the embedding result" do
        result = cloudflare_workers_ai.perform!(content)
        expect(result).to eq("embedding_result")
      end
    end

    context "when the response status is not 200" do
      let(:response_status) { 500 }
      let(:response_body) { "Internal Server Error" }

      it "raises a Net::HTTPBadResponse error" do
        allow(Rails.logger).to receive(:warn)
        expect { cloudflare_workers_ai.perform!(content) }.to raise_error(Net::HTTPBadResponse)
        expect(Rails.logger).to have_received(:warn).with(
          "Cloudflare Workers AI Embeddings failed with status: #{response_status} body: #{response_body}",
        )
      end
    end
  end
end

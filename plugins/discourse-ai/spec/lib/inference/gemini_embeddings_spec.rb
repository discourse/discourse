# frozen_string_literal: true

require "webmock/rspec"

RSpec.describe DiscourseAi::Inference::GeminiEmbeddings do
  subject(:gemini_embeddings) { described_class.new(endpoint, api_key, dimensions) }

  let(:api_key) { "test_api_key" }
  let(:endpoint) do
    "https://generativelanguage.googleapis.com/v1beta/models/embedding-001:embedContent"
  end
  let(:content) { "test content" }
  let(:dimensions) { nil }
  let(:headers) { { "Referer" => Discourse.base_url, "Content-Type" => "application/json" } }
  let(:url) { "#{endpoint}?key=#{api_key}" }

  before { enable_current_plugin }

  describe "#perform!" do
    context "when dimensions are not provided" do
      let(:payload) { { content: { parts: [{ text: content }] } }.to_json }

      before do
        stub_request(:post, url).with(body: payload, headers: headers).to_return(
          status: response_status,
          body: response_body,
        )
      end

      context "when the response status is 200" do
        let(:response_status) { 200 }
        let(:response_body) { { embedding: { values: [0.1, 0.2, 0.3] } }.to_json }

        it "returns the embedding values" do
          result = gemini_embeddings.perform!(content)
          expect(result).to eq([0.1, 0.2, 0.3])
        end
      end

      context "when the response status is not 200" do
        let(:response_status) { 500 }
        let(:response_body) { "Internal Server Error" }

        it "raises a Net::HTTPBadResponse error" do
          allow(Rails.logger).to receive(:warn)
          expect { gemini_embeddings.perform!(content) }.to raise_error(Net::HTTPBadResponse)
          expect(Rails.logger).to have_received(:warn).with(
            "Google Gemini Embeddings failed with status: #{response_status} body: #{response_body}",
          )
        end
      end
    end

    context "when dimensions are provided" do
      let(:dimensions) { 512 }
      let(:payload) do
        {
          content: {
            parts: [{ text: content }],
          },
          embedding_config: {
            output_dimensionality: dimensions,
          },
        }.to_json
      end

      before do
        stub_request(:post, url).with(body: payload, headers: headers).to_return(
          status: response_status,
          body: response_body,
        )
      end

      context "when the response status is 200" do
        let(:response_status) { 200 }
        let(:response_body) { { embedding: { values: [0.1, 0.2, 0.3] } }.to_json }

        it "includes embedding_config with output_dimensionality in the request" do
          result = gemini_embeddings.perform!(content)
          expect(result).to eq([0.1, 0.2, 0.3])
        end

        it "sends the correct payload with dimensions" do
          gemini_embeddings.perform!(content)
          expect(WebMock).to have_requested(:post, url).with(body: payload)
        end
      end
    end

    context "when dimensions are nil" do
      let(:dimensions) { nil }
      let(:payload) { { content: { parts: [{ text: content }] } }.to_json }

      before do
        stub_request(:post, url).with(body: payload, headers: headers).to_return(
          status: 200,
          body: { embedding: { values: [0.1, 0.2, 0.3] } }.to_json,
        )
      end

      it "does not include embedding_config in the request" do
        gemini_embeddings.perform!(content)
        expect(WebMock).to have_requested(:post, url).with(body: payload)
      end
    end
  end

  describe "#initialize" do
    it "stores the provided dimensions" do
      client = described_class.new(endpoint, api_key, 256)
      expect(client.instance_variable_get(:@dimensions)).to eq(256)
    end

    it "defaults dimensions to nil when not provided" do
      client = described_class.new(endpoint, api_key)
      expect(client.instance_variable_get(:@dimensions)).to be_nil
    end
  end
end

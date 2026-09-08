# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::Endpoints::GoogleVertexAi do
  subject(:endpoint) { described_class.new(model) }

  fab!(:user)

  let(:model) do
    Fabricate(
      :llm_model,
      name: "google/gemini-3.5-flash",
      provider: "google_vertex_ai",
      tokenizer: "DiscourseAi::Tokenizer::GeminiTokenizer",
      url: nil,
      api_key: nil,
      provider_params: {
        project_id: "discourse-project",
        region: "global",
      },
    )
  end

  before do
    enable_current_plugin
    described_class.reset_adc_token_cache!
  end

  after { described_class.reset_adc_token_cache! }

  def stub_metadata_token(token: "adc-token", expires_in: 3599)
    stub_request(
      :get,
      "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token",
    ).with(headers: { "Metadata-Flavor" => "Google" }).to_return(
      status: 200,
      body: { access_token: token, expires_in: expires_in, token_type: "Bearer" }.to_json,
    )
  end

  it "uses the global Vertex AI endpoint and strips the publisher prefix from model names" do
    expect(endpoint.send(:model_uri).to_s).to eq(
      "https://aiplatform.googleapis.com/v1/projects/discourse-project/locations/global/publishers/google/models/gemini-3.5-flash:generateContent",
    )
  end

  it "uses regional Vertex AI endpoints for regional provider params" do
    model.provider_params["region"] = "us-central1"

    expect(endpoint.send(:model_uri).to_s).to eq(
      "https://us-central1-aiplatform.googleapis.com/v1/projects/discourse-project/locations/us-central1/publishers/google/models/gemini-3.5-flash:generateContent",
    )
  end

  it "sends a Google Cloud bearer token" do
    endpoint.stubs(:access_token).returns("vertex-token")

    request = endpoint.send(:prepare_request, "{}")

    expect(request["Authorization"]).to eq("Bearer vertex-token")
  end

  it "strips unsupported generation parameters for Gemini 3.8" do
    SiteSetting.ai_llm_temperature_top_p_enabled = true
    model.update!(
      name: "google/gemini-3.8-flash",
      api_key: "vertex-token",
      provider_params: {
        project_id: "discourse-project",
        region: "global",
      },
    )
    request_body = nil
    url =
      "https://aiplatform.googleapis.com/v1/projects/discourse-project/locations/global/publishers/google/models/gemini-3.8-flash:generateContent"
    stub_request(:post, url).with(
      body:
        proc do |body|
          request_body = JSON.parse(body, symbolize_names: true)
          true
        end,
    ).to_return(
      status: 200,
      body: {
        candidates: [
          { content: { parts: [{ text: "Done" }], role: "model" }, finishReason: "STOP" },
        ],
      }.to_json,
    )

    expect(
      DiscourseAi::Completions::Llm.proxy(model).generate(
        "Think",
        user:,
        temperature: 0.4,
        top_p: 0.8,
        extra_model_params: {
          topK: 40,
          thinkingConfig: {
            thinkingBudget: 1_000,
          },
        },
      ),
    ).to eq("Done")
    expect(request_body[:generationConfig]).to be_empty
  end

  it "omits legacy thinking budgets for Gemini 3.8" do
    model.update!(
      name: "google/gemini-3.8-flash",
      api_key: "vertex-token",
      provider_params: {
        project_id: "discourse-project",
        region: "global",
        enable_thinking: true,
        thinking_tokens: 10_000,
      },
    )
    request_bodies = []
    url =
      "https://aiplatform.googleapis.com/v1/projects/discourse-project/locations/global/publishers/google/models/gemini-3.8-flash:generateContent"
    stub_request(:post, url).with(
      body:
        proc do |body|
          request_bodies << JSON.parse(body, symbolize_names: true)
          true
        end,
    ).to_return(
      status: 200,
      body: {
        candidates: [
          { content: { parts: [{ text: "Done" }], role: "model" }, finishReason: "STOP" },
        ],
      }.to_json,
    )

    llm = DiscourseAi::Completions::Llm.proxy(model)
    expect(llm.generate("Think", user:)).to eq("Done")
    expect(llm.generate("Think", user:, thinking_effort: "none")).to eq("Done")
    expect(request_bodies.map { |body| body[:generationConfig] }).to eq(
      [{}, { thinkingConfig: { thinkingLevel: "low" } }],
    )
  end

  describe "credential resolution" do
    it "prefers a configured API key over environment credentials" do
      model.update!(api_key: "configured-key")

      expect(endpoint.send(:access_token)).to eq("configured-key")
    end

    it "falls back to the metadata server token when no API key is configured" do
      stub_metadata_token(token: "adc-token")

      expect(endpoint.send(:access_token)).to eq("adc-token")
    end

    it "caches the metadata server token across endpoint instances" do
      metadata_stub = stub_metadata_token(token: "adc-token")

      expect(endpoint.send(:access_token)).to eq("adc-token")
      expect(described_class.new(model).send(:access_token)).to eq("adc-token")

      expect(metadata_stub).to have_been_requested.once
    end

    it "does not cache tokens that expire within the safety buffer" do
      metadata_stub = stub_metadata_token(token: "adc-token", expires_in: 30)

      expect(endpoint.send(:access_token)).to be_nil
      expect(described_class.new(model).send(:access_token)).to be_nil

      expect(metadata_stub).to have_been_requested.twice
    end

    it "returns nil when the metadata server is unavailable" do
      stub_request(
        :get,
        "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token",
      ).to_raise(Errno::ECONNREFUSED)

      expect(endpoint.send(:access_token)).to be_nil
    end
  end
end

# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::Endpoints::GoogleVertexAi do
  subject(:endpoint) { described_class.new(model) }

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

  before { enable_current_plugin }

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
end

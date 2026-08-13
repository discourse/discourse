# frozen_string_literal: true

require "webmock/rspec"

describe DiscourseAi::Inference::HuggingFaceTextEmbeddings do
  before do
    enable_current_plugin
    SiteSetting.ai_hugging_face_tei_reranker_endpoint = "https://reranker.example.com"
    SiteSetting.ai_hugging_face_tei_reranker_api_key = "secret-key"
  end

  it "sends an authenticated bounded reranker request" do
    stub_request(:post, "https://reranker.example.com/rerank").with(
      headers: {
        "Authorization" => "Bearer secret-key",
        "Content-Type" => "application/json",
        "Referer" => Discourse.base_url,
        "X-API-KEY" => "secret-key",
      },
      body: {
        query: "miyazaki",
        texts: ["Hayao Miyazaki films", "database backups"],
        truncate: true,
      }.to_json,
    ).to_return(status: 200, body: { results: [{ index: 0, score: 0.9 }] }.to_json)

    expect(described_class.rerank("miyazaki", ["Hayao Miyazaki films", "database backups"])).to eq(
      { results: [{ index: 0, score: 0.9 }] },
    )
  end
end

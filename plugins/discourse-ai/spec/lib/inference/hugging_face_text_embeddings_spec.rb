# frozen_string_literal: true

RSpec.describe DiscourseAi::Inference::HuggingFaceTextEmbeddings do
  let(:endpoint) { "https://embeddings.example.com" }
  let(:client) { described_class.new(endpoint, "secret") }

  before do
    stub_request(:post, endpoint).to_return(status: 401, body: { error: "invalid key" }.to_json)
  end

  it "changes only the embedding error contract" do
    expect { client.perform!("content") }.to raise_error(
      DiscourseAi::Inference::EmbeddingInferenceError,
    )
    expect { client.classify_by_sentiment!("content") }.to raise_error(Net::HTTPBadResponse)
  end
end

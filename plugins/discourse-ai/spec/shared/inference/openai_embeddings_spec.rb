# frozen_string_literal: true

describe DiscourseAi::Inference::OpenAiEmbeddings do
  let(:api_key) { "123456" }
  let(:dimensions) { 1000 }
  let(:model) { "text-embedding-ada-002" }

  before { enable_current_plugin }

  it "supports azure embeddings" do
    azure_url =
      "https://my-company.openai.azure.com/openai/deployments/embeddings-deployment/embeddings?api-version=2023-05-15"

    body_json = {
      usage: {
        prompt_tokens: 1,
        total_tokens: 1,
      },
      data: [{ object: "embedding", embedding: [0.0, 0.1] }],
    }.to_json

    stub_request(:post, azure_url).with(
      body: "{\"model\":\"text-embedding-ada-002\",\"input\":\"hello\"}",
      headers: {
        "Api-Key" => api_key,
        "Content-Type" => "application/json",
      },
    ).to_return(status: 200, body: body_json, headers: {})

    result =
      DiscourseAi::Inference::OpenAiEmbeddings.new(azure_url, api_key, model, nil).perform!("hello")

    expect(result).to eq([0.0, 0.1])
  end

  it "supports openai embeddings" do
    url = "https://api.openai.com/v1/embeddings"
    body_json = {
      usage: {
        prompt_tokens: 1,
        total_tokens: 1,
      },
      data: [{ object: "embedding", embedding: [0.0, 0.1] }],
    }.to_json

    body = { model: model, input: "hello", dimensions: dimensions }.to_json

    stub_request(:post, url).with(
      body: body,
      headers: {
        "Authorization" => "Bearer #{api_key}",
        "Content-Type" => "application/json",
      },
    ).to_return(status: 200, body: body_json, headers: {})

    result =
      DiscourseAi::Inference::OpenAiEmbeddings.new(url, api_key, model, dimensions).perform!(
        "hello",
      )

    expect(result).to eq([0.0, 0.1])
  end
end

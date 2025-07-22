# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::Endpoints::OpenRouter do
  fab!(:user)
  fab!(:open_router_model)

  subject(:endpoint) { described_class.new(open_router_model) }

  before { enable_current_plugin }

  it "supports provider quantization and order selection" do
    open_router_model.provider_params["provider_quantizations"] = "int8,int16"
    open_router_model.provider_params["provider_order"] = "Google, Amazon Bedrock"
    open_router_model.save!

    parsed_body = nil
    stub_request(:post, open_router_model.url).with(
      body: proc { |body| parsed_body = JSON.parse(body, symbolize_names: true) },
      headers: {
        "Content-Type" => "application/json",
        "X-Title" => "Discourse AI",
        "HTTP-Referer" => "https://www.discourse.org/ai",
        "Authorization" => "Bearer 123",
      },
    ).to_return(
      status: 200,
      body: { "choices" => [message: { role: "assistant", content: "world" }] }.to_json,
    )

    proxy = DiscourseAi::Completions::Llm.proxy("custom:#{open_router_model.id}")
    result = proxy.generate("hello", user: user)

    expect(result).to eq("world")

    expected = {
      model: "openrouter-1.0",
      messages: [
        { role: "system", content: "You are a helpful bot" },
        { role: "user", content: "hello" },
      ],
      provider: {
        quantizations: %w[int8 int16],
        order: ["Google", "Amazon Bedrock"],
      },
    }

    expect(parsed_body).to eq(expected)
  end

  it "excludes disabled parameters from the request" do
    open_router_model.update!(provider_params: { disable_top_p: true, disable_temperature: true })

    parsed_body = nil
    stub_request(:post, open_router_model.url).with(
      body: proc { |body| parsed_body = JSON.parse(body, symbolize_names: true) },
      headers: {
        "Content-Type" => "application/json",
        "X-Title" => "Discourse AI",
        "HTTP-Referer" => "https://www.discourse.org/ai",
        "Authorization" => "Bearer 123",
      },
    ).to_return(
      status: 200,
      body: { "choices" => [message: { role: "assistant", content: "test response" }] }.to_json,
    )

    proxy = DiscourseAi::Completions::Llm.proxy("custom:#{open_router_model.id}")

    # Request with parameters that should be ignored
    proxy.generate("test", user: user, top_p: 0.9, temperature: 0.8, max_tokens: 500)

    # Verify disabled parameters aren't included
    expect(parsed_body).not_to have_key(:top_p)
    expect(parsed_body).not_to have_key(:temperature)

    # Verify other parameters still work
    expect(parsed_body).to have_key(:max_tokens)
    expect(parsed_body[:max_tokens]).to eq(500)
  end
end

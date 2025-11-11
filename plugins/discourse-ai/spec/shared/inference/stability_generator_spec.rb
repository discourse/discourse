# frozen_string_literal: true

describe DiscourseAi::Inference::StabilityGenerator do
  def gen(prompt)
    DiscourseAi::Inference::StabilityGenerator.perform!(prompt)
  end

  let :sd3_response do
    { image: "BASE64", seed: 1 }.to_json
  end

  before { enable_current_plugin }

  it "is able to generate sd3 images" do
    SiteSetting.ai_stability_engine = "sd3"
    SiteSetting.ai_stability_api_url = "http://www.a.b.c"
    SiteSetting.ai_stability_api_key = "123"

    # webmock does not support multipart form data :(
    stub_request(:post, "http://www.a.b.c/v2beta/stable-image/generate/sd3").with(
      headers: {
        "Accept" => "application/json",
        "Authorization" => "Bearer 123",
        "Content-Type" => "multipart/form-data",
        "Host" => "www.a.b.c",
        "User-Agent" => DiscourseAi::AiBot::USER_AGENT,
      },
    ).to_return(status: 200, body: sd3_response, headers: {})

    json =
      DiscourseAi::Inference::StabilityGenerator.perform!(
        "a cow",
        aspect_ratio: "16:9",
        image_count: 2,
      )

    expect(json).to eq(artifacts: [{ base64: "BASE64", seed: 1 }, { base64: "BASE64", seed: 1 }])
  end

  it "sets dimensions to 512x512 for non XL model" do
    SiteSetting.ai_stability_engine = "stable-diffusion-v1-5"
    SiteSetting.ai_stability_api_url = "http://www.a.b.c"
    SiteSetting.ai_stability_api_key = "123"

    stub_request(:post, "http://www.a.b.c/v1/generation/stable-diffusion-v1-5/text-to-image")
      .with do |request|
        json = JSON.parse(request.body)
        expect(json["text_prompts"][0]["text"]).to eq("a cow")
        expect(json["width"]).to eq(512)
        expect(json["height"]).to eq(512)
        expect(request.headers["Authorization"]).to eq("Bearer 123")
        expect(request.headers["Content-Type"]).to eq("application/json")
        true
      end
      .to_return(status: 200, body: "{}", headers: {})

    gen("a cow")
  end

  it "sets dimensions to 1024x1024 for XL model" do
    SiteSetting.ai_stability_engine = "stable-diffusion-xl-1024-v1-0"
    SiteSetting.ai_stability_api_url = "http://www.a.b.c"
    SiteSetting.ai_stability_api_key = "123"
    stub_request(
      :post,
      "http://www.a.b.c/v1/generation/stable-diffusion-xl-1024-v1-0/text-to-image",
    )
      .with do |request|
        json = JSON.parse(request.body)
        expect(json["text_prompts"][0]["text"]).to eq("a cow")
        expect(json["width"]).to eq(1024)
        expect(json["height"]).to eq(1024)
        expect(request.headers["Authorization"]).to eq("Bearer 123")
        expect(request.headers["Content-Type"]).to eq("application/json")
        true
      end
      .to_return(status: 200, body: "{}", headers: {})

    gen("a cow")
  end
end

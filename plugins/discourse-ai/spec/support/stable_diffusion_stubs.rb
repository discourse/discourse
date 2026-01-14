# frozen_string_literal: true

class StableDiffusionStubs
  include RSpec::Matchers

  def stub_response(prompt, images)
    artifacts = images.map { |i| { base64: i } }

    WebMock
      .stub_request(
        :post,
        "https://api.stability.dev/v1/generation/#{SiteSetting.ai_stability_engine}/text-to-image",
      )
      .with do |request|
        json = JSON.parse(request.body, symbolize_names: true)
        expect(json[:text_prompts][0][:text]).to eq(prompt)
        true
      end
      .to_return(status: 200, body: { artifacts: artifacts }.to_json)
  end
end

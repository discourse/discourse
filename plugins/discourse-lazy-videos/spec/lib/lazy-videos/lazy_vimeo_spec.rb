# frozen_string_literal: true

RSpec.describe Onebox::Engine::VimeoOnebox do
  before do
    stub_request(
      :get,
      "https://vimeo.com/api/oembed.json?url=https://vimeo.com/192207770/0faf1dd09d",
    ).to_return(
      status: 200,
      body:
        JSON.dump(
          type: "video",
          version: "1.0",
          provider_name: "Vimeo",
          provider_url: "https://vimeo.com/",
          html:
            "<iframe src=\"https://player.vimeo.com/video/192207770?h=0faf1dd09d&amp;app_id=122963\" width=\"640\" height=\"272\" frameborder=\"0\" allow=\"autoplay; fullscreen; picture-in-picture\" allowfullscreen></iframe>",
          width: 640,
          height: 272,
          video_id: 192_207_770,
          uri: "/videos/192207770:0faf1dd09d",
        ),
    )
  end

  it "creates a lazy video container for public vidos" do
    expect(Onebox.preview("https://vimeo.com/192207770/0faf1dd09d").to_s).not_to match(
      /lazy-video-container/,
    )
  end
end

# frozen_string_literal: true

RSpec.describe Onebox::Engine::AudioComOnebox do
  before do
    stub_request(
      :get,
      "https://api.audio.com/oembed?maxheight=228&url=https://audio.com/agilov/audio/discourse-onebox-test-audio",
    ).to_return(status: 200, body: onebox_response("audio_com_audio_oembed"))

    stub_request(
      :get,
      "https://api.audio.com/oembed?url=https://audio.com/agilov/collections/discourse-test-collection",
    ).to_return(status: 200, body: onebox_response("audio_com_collection_oembed"))
  end

  it "has the iframe with the correct audio" do
    expect(Onebox.preview("https://audio.com/agilov/audio/discourse-onebox-test-audio").to_s).to match(
      %r{<iframe src="https://audio\.com/embed/audio/1773123508340882},
    )
  end

  it "has the iframe with the correct collection" do
    expect(Onebox.preview("https://audio.com/agilov/collections/discourse-test-collection").to_s).to match(
      %r{<iframe src="https://audio\.com/embed/collection/1773124246389900},
    )
  end
end

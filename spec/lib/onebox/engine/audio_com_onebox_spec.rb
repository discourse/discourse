# frozen_string_literal: true

RSpec.describe Onebox::Engine::AudioComOnebox do
  it "has the iframe with the correct audio" do
    stub_request(
      :get,
      "https://api.audio.com/oembed?maxheight=228&url=https://audio.com/agilov/audio/discourse-onebox-test-audio",
    ).to_return(status: 200, body: onebox_response("audio_com_audio_oembed"))
    expect(
      Onebox.preview("https://audio.com/agilov/audio/discourse-onebox-test-audio").to_s,
    ).to match(%r{<iframe src="https://audio\.com/embed/audio/1773123508340882})
  end

  it "has the iframe with the correct collection" do
    stub_request(
      :get,
      "https://api.audio.com/oembed?url=https://audio.com/agilov/collections/discourse-test-collection",
    ).to_return(status: 200, body: onebox_response("audio_com_collection_oembed"))
    expect(
      Onebox.preview("https://audio.com/agilov/collections/discourse-test-collection").to_s,
    ).to match(%r{<iframe src="https://audio\.com/embed/collection/1773124246389900})
  end

  describe ".===" do
    it "matches valid URL" do
      valid_url = URI("https://audio.com/path/to/resource")
      expect(described_class === valid_url).to eq(true)
    end

    it "matches valid URL without path" do
      valid_url = URI("https://audio.com")
      expect(described_class === valid_url).to eq(true)
    end

    it "does not match invalid URL with subdomain" do
      invalid_url = URI("https://sub.audio.com/path/to/resource")
      expect(described_class === invalid_url).to eq(false)
    end

    it "does not match invalid URL with valid domain as part of another domain" do
      malicious_url = URI("https://audio.com.malicious.com")
      expect(described_class === malicious_url).to eq(false)
    end
  end
end

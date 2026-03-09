# frozen_string_literal: true

RSpec.describe Onebox::Engine::VideoOnebox do
  it "supports ogv" do
    expect(
      Onebox.preview(
        "http://upload.wikimedia.org/wikipedia/commons/3/37/STS-134_launch_2.ogv",
      ).to_s,
    ).to match(/<video/)
  end

  it "supports mp4" do
    expect(Onebox.preview("http://download.wavetlan.com/svv/dev/test.mp4").to_s).to match(/<video/)
  end

  it "supports mov" do
    expect(
      Onebox.preview("http://download.wavetlan.com/SVV/Media/HTTP/BlackBerry.MOV").to_s,
    ).to match(/<video/)
  end

  it "supports webm" do
    expect(Onebox.preview("http://video.webmfiles.org/big-buck-bunny_trailer.webm").to_s).to match(
      /<video/,
    )
  end

  it "supports URLs with query parameters" do
    expect(
      Onebox.preview("http://video.webmfiles.org/big-buck-bunny_trailer.webm?foo=bar").to_s,
    ).to match(/<video/)
  end

  it "supports protocol relative URLs" do
    expect(Onebox.preview("//video.webmfiles.org/big-buck-bunny_trailer.webm").to_s).to match(
      /<video/,
    )
  end

  it "includes a fallback direct link to the video" do
    expect(Onebox.preview("http://download.wavetlan.com/svv/dev/test.mp4").to_s).to match(/<a.*mp4/)
  end

  it "respects the disable_media_download_controls option" do
    expect(
      Onebox.preview(
        "http://download.wavetlan.com/svv/dev/test.mp4",
        disable_media_download_controls: true,
      ).to_s,
    ).to include("controlslist=\"nodownload\"")
  end

  describe "Dropbox videos" do
    it "transforms old format Dropbox URLs to use dl.dropboxusercontent.com" do
      url = "https://www.dropbox.com/s/abcd1234/video.mp4"
      html = Onebox.preview(url).to_s
      expect(html).to include("dl.dropboxusercontent.com/s/abcd1234/video.mp4")
      expect(html).not_to include("www.dropbox.com")
    end

    it "transforms new format Dropbox URLs to use dl.dropboxusercontent.com with raw=1" do
      url = "https://www.dropbox.com/scl/fi/abc123/video.mp4?rlkey=xyz789&st=test123"
      html = Onebox.preview(url).to_s
      expect(html).to include("dl.dropboxusercontent.com")
      expect(html).to include("raw=1")
      expect(html).not_to include("www.dropbox.com")
    end

    it "ensures raw=1 parameter is present for new format Dropbox URLs" do
      url = "https://www.dropbox.com/scl/fi/abc123/video.mp4?rlkey=xyz789"
      html = Onebox.preview(url).to_s
      expect(html).to include("raw=1")
    end

    it "preserves existing raw=1 parameter in new format Dropbox URLs" do
      url = "https://www.dropbox.com/scl/fi/abc123/video.mp4?rlkey=xyz789&raw=1"
      html = Onebox.preview(url).to_s
      expect(html).to include("raw=1")
      expect(html).to include("dl.dropboxusercontent.com")
    end
  end
end

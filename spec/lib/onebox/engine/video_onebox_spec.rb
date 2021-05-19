# frozen_string_literal: true

require "rails_helper"

describe Onebox::Engine::VideoOnebox do
  it "supports ogv" do
    expect(Onebox.preview('http://upload.wikimedia.org/wikipedia/commons/3/37/STS-134_launch_2.ogv').to_s).to match(/<video/)
  end

  it "supports mp4" do
    expect(Onebox.preview('http://download.wavetlan.com/svv/dev/test.mp4').to_s).to match(/<video/)
  end

  it "supports mov" do
    expect(Onebox.preview('http://download.wavetlan.com/SVV/Media/HTTP/BlackBerry.MOV').to_s).to match(/<video/)
  end

  it "supports webm" do
    expect(Onebox.preview('http://video.webmfiles.org/big-buck-bunny_trailer.webm').to_s).to match(/<video/)
  end

  it "supports URLs with query parameters" do
    expect(Onebox.preview('http://video.webmfiles.org/big-buck-bunny_trailer.webm?foo=bar').to_s).to match(/<video/)
  end

  it "supports protocol relative URLs" do
    expect(Onebox.preview('//video.webmfiles.org/big-buck-bunny_trailer.webm').to_s).to match(/<video/)
  end

  it "includes a fallback direct link to the video" do
    expect(Onebox.preview('http://download.wavetlan.com/svv/dev/test.mp4').to_s).to match(/<a.*mp4/)
  end

  it "respects the disable_media_download_controls option" do
    expect(Onebox.preview('http://download.wavetlan.com/svv/dev/test.mp4', disable_media_download_controls: true).to_s).to include("controlslist=\"nodownload\"")
  end
end

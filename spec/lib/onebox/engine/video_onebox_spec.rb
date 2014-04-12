require "spec_helper"

describe Onebox::Engine::VideoOnebox do
  it "supports ogv" do
    Onebox.preview('http://upload.wikimedia.org/wikipedia/commons/3/37/STS-134_launch_2.ogv').to_s.should match(/<video/)
  end

  it "supports mp4" do
    Onebox.preview('http://download.wavetlan.com/svv/dev/test.mp4').to_s.should match(/<video/)
  end

  it "supports mov" do
    Onebox.preview('http://download.wavetlan.com/SVV/Media/HTTP/BlackBerry.mov').to_s.should match(/<video/)
  end

  it "supports webm" do
    Onebox.preview('http://video.webmfiles.org/big-buck-bunny_trailer.webm').to_s.should match(/<video/)
  end

  it "supports URLs with query parameters" do
    Onebox.preview('http://video.webmfiles.org/big-buck-bunny_trailer.webm?foo=bar').to_s.should match(/<video/)
  end

  it "supports protocol relative URLs" do
    Onebox.preview('//video.webmfiles.org/big-buck-bunny_trailer.webm').to_s.should match(/<video/)
  end

  it "includes a fallback direct link to the video" do
    Onebox.preview('http://download.wavetlan.com/svv/dev/test.mp4').to_s.should match(/<a.*mp4/)
  end
end

require "spec_helper"

describe Onebox::Engine::AudioOnebox do
  it "supports ogg" do
    Onebox.preview('http://upload.wikimedia.org/wikipedia/commons/c/c8/Example.ogg').to_s.should match(/<audio/)
  end

  it "supports mp3" do
    Onebox.preview('http://kolber.github.io/audiojs/demos/mp3/juicy.mp3').to_s.should match(/<audio/)
  end

  it "supports wav" do
    Onebox.preview('http://download.wavetlan.com/SVV/Media/HTTP/sample14.wav').to_s.should match(/<audio/)
  end

  it "supports URLs with query parameters" do
    Onebox.preview('https://upload.wikimedia.org/wikipedia/commons/c/c8/Example.ogg?foo=bar').to_s.should match(/<audio/)
  end

  it "supports protocol relative URLs" do
    Onebox.preview('//upload.wikimedia.org/wikipedia/commons/c/c8/Example.ogg').to_s.should match(/<audio/)
  end
  
  it "includes a fallback direct link to the audio" do
    Onebox.preview('http://kolber.github.io/audiojs/demos/mp3/juicy.mp3').to_s.should match(/<a.*mp3/)
  end
end

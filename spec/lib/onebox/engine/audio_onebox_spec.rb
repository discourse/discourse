# frozen_string_literal: true

require "rails_helper"

describe Onebox::Engine::AudioOnebox do
  it "supports ogg" do
    expect(Onebox.preview('http://upload.wikimedia.org/wikipedia/commons/c/c8/Example.ogg').to_s).to match(/<audio/)
  end

  it "supports mp3" do
    expect(Onebox.preview('http://kolber.github.io/audiojs/demos/mp3/juicy.MP3').to_s).to match(/<audio/)
  end

  it "supports wav" do
    expect(Onebox.preview('http://download.wavetlan.com/SVV/Media/HTTP/sample14.wav').to_s).to match(/<audio/)
  end

  it "supports m4a" do
    expect(Onebox.preview('http://techslides.com/demos/samples/sample.m4a').to_s).to match(/<audio/)
  end

  it "supports URLs with query parameters" do
    expect(Onebox.preview('https://upload.wikimedia.org/wikipedia/commons/c/c8/Example.ogg?foo=bar').to_s).to match(/<audio/)
  end

  it "supports protocol relative URLs" do
    expect(Onebox.preview('//upload.wikimedia.org/wikipedia/commons/c/c8/Example.ogg').to_s).to match(/<audio/)
  end

  it "includes a fallback direct link to the audio" do
    expect(Onebox.preview('http://kolber.github.io/audiojs/demos/mp3/juicy.mp3').to_s).to match(/<a.*mp3/)
  end

  it "respects the disable_media_downloads option" do
    expect(Onebox.preview('http://kolber.github.io/audiojs/demos/mp3/juicy.MP3', disable_media_download_controls: true).to_s).to include("controlslist=\"nodownload\"")
  end
end

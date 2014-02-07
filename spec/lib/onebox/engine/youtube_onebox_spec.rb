require 'spec_helper'

describe Onebox::Engine::YoutubeOnebox do
  before do
    fake("https://www.youtube.com/watch?v=21Lk4YiASMo", response("youtube"))
    fake("http://www.youtube.com/oembed?format=json&url=http%3A%2F%2Fwww.youtube.com%2Fwatch%3Fv%3D21Lk4YiASMo", response("youtube-json"))
  end

  it "should add wmode=opaque" do
    Onebox.preview('https://www.youtube.com/watch?v=21Lk4YiASMo').to_s.should match(/wmode=opaque/)
  end

  it "should rewrite URLs to be agnostic" do
    Onebox.preview('https://www.youtube.com/watch?v=21Lk4YiASMo').to_s.should match(/"\/\//)
  end
end


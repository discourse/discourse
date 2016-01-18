require "spec_helper"

describe Onebox::Engine::PastebinOnebox do
  before do
    fake("http://pastebin.com/raw/YH8wQDi8", response("pastebin.response"))
  end

  it "returns iframe with pastebin embed URL" do
    expect(Onebox.preview('http://pastebin.com/YH8wQDi8').to_s).to match("<iframe src='//pastebin.com/embed_iframe/YH8wQDi8' style='border:none;width:100%;max-height:100px;'></iframe>")
  end

  it "supports pastebin raw link" do
    expect(Onebox.preview('http://pastebin.com/raw/YH8wQDi8').to_s).to match(/pastebin.com\/embed_iframe\/YH8wQDi8/)
  end

  it "supports pastebin download link" do
    expect(Onebox.preview('http://pastebin.com/download/YH8wQDi8').to_s).to match(/pastebin.com\/embed_iframe\/YH8wQDi8/)
  end

  it "supports pastebin embed link" do
    expect(Onebox.preview('http://pastebin.com/embed/YH8wQDi8').to_s).to match(/pastebin.com\/embed_iframe\/YH8wQDi8/)
  end
end

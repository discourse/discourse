require "spec_helper"

describe Onebox::Engine::SteamStoreWidgetOnebox do

  before do
    fake("http://store.steampowered.com/app/10/", response("steamstorewidget"))
  end

  it "supports iframe widget render" do
    expect(Onebox.preview('http://store.steampowered.com/app/10/').to_s).to match(/<iframe/)
  end

  it "supports http app to https widget resource" do
    expect(Onebox.preview('http://store.steampowered.com/app/10/').to_s).to match('https://store.steampowered.com/widget/10/')
  end
 
  it "supports a simple preview without an iframe" do
    expect(Onebox.preview('http://store.steampowered.com/app/10/').placeholder_html.to_s).to match('Steam Store Widget onebox preview')
  end
 
end

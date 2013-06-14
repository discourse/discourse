# encoding: utf-8

require 'spec_helper'
require 'oneboxer'
require 'oneboxer/apple_app_onebox'

describe Oneboxer::AppleAppOnebox do
  before(:each) do
    @o = Oneboxer::AppleAppOnebox.new("https://itunes.apple.com/us/app/minecraft-pocket-edition-lite/id479651754")
    FakeWeb.register_uri(:get, @o.translate_url, response: fixture_file('oneboxer/apple.response'))
  end

  it "generates the expected onebox for Apple app" do
    @o.onebox.should match_html expected_apple_app_result
  end

private
  def expected_apple_app_result
    <<EXPECTED
<div class='onebox-result'>
    <div class='source'>
      <div class='info'>
        <a href='https://itunes.apple.com/us/app/minecraft-pocket-edition-lite/id479651754' class="track-link" target="_blank">
          <img class='favicon' src="/assets/favicons/apple.png"> itunes.apple.com
        </a>
      </div>
    </div>
  <div class='onebox-result-body'>
    <img src="http://a5.mzstatic.com/us/r1000/087/Purple/99/2f/dd/mzl.erzwvjsi.175x175-75.jpg" class="thumbnail">
    <h3><a href="https://itunes.apple.com/us/app/minecraft-pocket-edition-lite/id479651754" target="_blank">Minecraft – Pocket Edition Lite</a></h3>
    
      Imagine it, build it. Create worlds on the go with Minecraft - Pocket EditionThis is the Lite version of Minecraft - Pocket Edition. Minecraft - Pocket Edition allows you to build on the go. Use blocks to create masterpieces as you travel, hangout with friends, sit at the park, the possibilities are endless. Move beyond the limits of your computer and play Minecraft everywhere you go.Limitations of the Lite version* The world is not saved between sessions* Multiplayer worlds can not be copied to 
  </div>
  <div class='clearfix'></div>
</div>
EXPECTED
  end
end

# encoding: utf-8

require 'spec_helper'
require 'oneboxer'
require 'oneboxer/wikipedia_onebox'

describe Oneboxer::WikipediaOnebox do

  it "generates the expected onebox for Wikipedia" do
    o = Oneboxer::WikipediaOnebox.new('http://en.wikipedia.org/wiki/Ruby')
    FakeWeb.register_uri(:get, o.translate_url, response: fixture_file('oneboxer/wikipedia.response'))
    FakeWeb.register_uri(:get, 'http://en.m.wikipedia.org/wiki/Ruby', response: fixture_file('oneboxer/wikipedia_redirected.response'))
    o.onebox.should match_html expected_wikipedia_result
  end

  it "accepts .com extention" do
    o = Oneboxer::WikipediaOnebox.new('http://en.wikipedia.com/wiki/Postgres')
    o.translate_url.should == 'http://en.m.wikipedia.org/w/index.php?title=Postgres'
  end

  it "encodes identifier" do
    o = Oneboxer::WikipediaOnebox.new('http://en.wikipedia.com/wiki/Café')
    o.translate_url.should == 'http://en.m.wikipedia.org/w/index.php?title=Caf%C3%A9'
  end

  it "defaults to en locale" do
    o = Oneboxer::WikipediaOnebox.new('http://wikipedia.org/wiki/Ruby_on_rails')
    o.translate_url.should == 'http://en.m.wikipedia.org/w/index.php?title=Ruby_on_rails'
  end

  it "generates localized url" do
    o = Oneboxer::WikipediaOnebox.new('http://fr.wikipedia.org/wiki/Ruby')
    o.translate_url.should == 'http://fr.m.wikipedia.org/w/index.php?title=Ruby'
  end

private
  def expected_wikipedia_result
    <<EXPECTED
<div class='onebox-result'>
    <div class='source'>
      <div class='info'>
        <a href='http://en.wikipedia.org/wiki/Ruby' class="track-link" target="_blank">
          <img class='favicon' src="/assets/favicons/wikipedia.png"> en.wikipedia.org
        </a>
      </div>
    </div>
  <div class='onebox-result-body'>
    <img src="http://upload.wikimedia.org/wikipedia/commons/thumb/8/80/Ruby_-_Winza%2C_Tanzania.jpg/220px-Ruby_-_Winza%2C_Tanzania.jpg" class="thumbnail">
    <h3><a href="http://en.wikipedia.org/wiki/Ruby" target="_blank">Ruby</a></h3>
    
      A ruby is a pink to blood-red colored gemstone, a variety of the mineral corundum (aluminium oxide). The red color is caused mainly by the presence of the element chromium. Its name comes from ruber, Latin for red. Other varieties of gem-quality corundum are called sapphires. The ruby is considered one of the four precious stones, together with the sapphire, the emerald, and the diamond. Prices of rubies are primarily determined by color. The brightest and most valuable "red" called pigeon blood-...
  </div>
  <div class='clearfix'></div>
</div>
EXPECTED
  end
end

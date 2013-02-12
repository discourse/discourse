# encoding: utf-8

require 'spec_helper'
require 'oneboxer'
require 'oneboxer/wikipedia_onebox'

describe Oneboxer::WikipediaOnebox do 
  it "generates the expected onebox for Wikipedia" do
    o = Oneboxer::WikipediaOnebox.new("http://en.wikipedia.org/wiki/Ruby")
    o.onebox.should == expected_wikipedia_result
  end
  
private
  def expected_wikipedia_result
    <<EXPECTED
<div class='onebox-result'>
    <div class='source'>
      <div class='info'>
        <a href='http://en.wikipedia.org/wiki/Ruby' target="_blank">
          <img class='favicon' src="/assets/favicons/wikipedia.png"> wikipedia.org
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
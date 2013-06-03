# encoding: utf-8

require 'spec_helper'
require 'oneboxer'
require 'oneboxer/findery_onebox'

describe Oneboxer::FinderyOnebox do
  before(:each) do
    @o = Oneboxer::FinderyOnebox.new("https://findery.com/burritojustice/notes/folsom-st-grounds")
    FakeWeb.register_uri(:get, @o.translate_url, response: fixture_file('oneboxer/findery.response'))
  end

  it "generates the expected onebox for a Findery note" do
    @o.onebox.should == expected_findery_result
  end

private
  def expected_findery_result
    <<EXPECTED
<div class='onebox-result'>
    <div class='source'>
      <div class='info'>
	<a href='https://findery.com/burritojustice/notes/folsom-st-grounds' class="track-link" target="_blank">
	  <img class='favicon' src="/assets/favicons/findery.png"> findery.com
	</a>
      </div>
    </div>
  <div class='onebox-result-body'>
    <img src="http://images1.findery.com/863289496013/7749939/488xN?1346377479" class="thumbnail">
    <h3><a href="https://findery.com/burritojustice/notes/folsom-st-grounds" target="_blank">Folsom St Grounds</a></h3>
    <h4>burritojustice</h4>

	<p>1899? Gone by 1903. Now a Muni Yard.
</p> <p>Not sure if it was the home to professional baseball, but football games were played there. It was the site of the 1900 Stanford/Cal Big Game tragedy -- people watching the game on the roof on top of the steel mill across 17th St fell to their deaths.
</p> <p><a href="http://www.sfweekly.com/2012-08-15/news/football-san-francisco-and-pacific-glass-works-history-sports-tragedy/">http://www.sfweekly.com/2012-08-15/news/football-san-francisco-and-pacific-glass-works-history-sports-tragedy/</a>
</p> <p>More references on it: (It was sometimes called Rec Grounds.)
<br><a href="http://www.outsidelands.org/richmond-grounds.php">http://www.outsidelands.org/richmond-grounds.php</a>
<br><a href="http://www.la84foundation.org/SportsLibrary/CFHSN/CFHSNv15/CFHSNv15n2c.pdf">http://www.la84foundation.org/SportsLibrary/CFHSN/CFHSNv15/CFHSNv15n2c.pdf</a></p>

  </div>
  <div class='clearfix'></div>
</div>
EXPECTED
  end
end

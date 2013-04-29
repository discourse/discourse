# encoding: utf-8

require 'spec_helper'
require 'oneboxer'
require 'oneboxer/rottentomatoes_onebox'

describe Oneboxer::RottentomatoesOnebox do
  it 'translates the URL' do
    o = Oneboxer::RottentomatoesOnebox.new('http://www.rottentomatoes.com/m/the_big_wedding_2013/')
    expect(o.translate_url).to eq("http://api.rottentomatoes.com/api/public/v1.0/movies.json?apikey=#{Oneboxer::RottentomatoesOnebox::API_KEY}&q=the%20big%20wedding%202013%20&page_limit=1&page=1")
  end

  it 'generates the expected onebox for a fresh movie' do
    o = Oneboxer::RottentomatoesOnebox.new('http://www.rottentomatoes.com/m/mud_2012/')
    FakeWeb.register_uri(:get, o.translate_url, response: fixture_file('oneboxer/rottentomatoes_fresh.response'))
    expect(o.onebox.gsub('&#39;', "'")).to eq(expected_fresh_result)
  end

  it 'generates the expected onebox for a rotten movie' do
    o = Oneboxer::RottentomatoesOnebox.new('http://www.rottentomatoes.com/m/the_big_wedding_2013/')
    FakeWeb.register_uri(:get, o.translate_url, response: fixture_file('oneboxer/rottentomatoes_rotten.response'))
    expect(o.onebox).to eq(expected_rotten_result)
  end

  it 'generates the expected onebox for a movie with an incomplete description' do
    o = Oneboxer::RottentomatoesOnebox.new('http://www.rottentomatoes.com/m/gunde_jaari_gallanthayyinde/')
    FakeWeb.register_uri(:get, o.translate_url, response: fixture_file('oneboxer/rottentomatoes_incomplete.response'))
    expect(o.onebox).to eq(expected_incomplete_result)
  end

private
  def expected_fresh_result
    <<EXPECTED
<div class='onebox-result'>
    <div class='source'>
      <div class='info'>
        <a href='http://www.rottentomatoes.com/m/mud_2012/' class="track-link" target="_blank">
          <img class='favicon' src="/assets/favicons/rottentomatoes.png"> rottentomatoes.com
        </a>
      </div>
    </div>
  <div class='onebox-result-body'>
    <img src="http://content7.flixster.com/movie/11/16/93/11169361_pro.jpg" class="thumbnail">
    <h3><a href="http://www.rottentomatoes.com/m/mud_2012/" target="_blank">Mud</a></h3>

      <img class="verdict" src=http://images.rottentomatoescdn.com/images/icons/rt.fresh.med.png><b>98%</b> of critics liked it.
      <img class="popcorn" src=http://images.rottentomatoescdn.com/images/icons/popcorn_27x31.png><b>87%</b> of users liked it.<br />
    <b>Cast:</b> Matthew McConaughey, Reese Witherspoon, Tye Sheridan<br />
    <b>Theater Release:</b> Apr 26, 2013<br />
    <b>Running Time:</b> 130 minutes<br />
    <b>Rated: </b> PG-13<br />
    Mud is an adventure about two boys, Ellis and his friend Neckbone, who find a man named Mud hiding out on an island in the Mississippi. Mud describes fantastic scenarios-he killed a man in Texas and vengeful bounty hunters are coming to get him. He says he is planning to meet and escape with the love of his life, Juniper, who is waiting for him in town. Skeptical but intrigued, Ellis and Neckbone agree to help him. It isn't long until Mud's vision...
  </div>
  <div class='clearfix'></div>
</div>
EXPECTED
  end

  def expected_rotten_result
    <<EXPECTED
<div class='onebox-result'>
    <div class='source'>
      <div class='info'>
        <a href='http://www.rottentomatoes.com/m/the_big_wedding_2013/' class="track-link" target="_blank">
          <img class='favicon' src="/assets/favicons/rottentomatoes.png"> rottentomatoes.com
        </a>
      </div>
    </div>
  <div class='onebox-result-body'>
    <img src="http://content8.flixster.com/movie/11/16/87/11168754_pro.jpg" class="thumbnail">
    <h3><a href="http://www.rottentomatoes.com/m/the_big_wedding_2013/" target="_blank">The Big Wedding</a></h3>

      <img class="verdict" src=http://images.rottentomatoescdn.com/images/icons/rt.rotten.med.png><b>6%</b> of critics liked it.
      <img class="popcorn" src=http://images.rottentomatoescdn.com/images/icons/popcorn_27x31.png><b>79%</b> of users liked it.<br />
    <b>Cast:</b> Robert De Niro, Diane Keaton, Susan Sarandon<br />
    <b>Theater Release:</b> Apr 26, 2013<br />
    <b>Running Time:</b> 89 minutes<br />
    <b>Rated: </b> R<br />
    With an all-star cast led by Robert De Niro, Katherine Heigl, Diane Keaton, Amanda Seyfried, Topher Grace, with Susan Sarandon and Robin Williams, THE BIG WEDDING is an uproarious romantic comedy about a charmingly modern family trying to survive a weekend wedding celebration that has the potential to become a full blown family fiasco. To the amusement of their adult children and friends, long divorced couple Don and Ellie Griffin (De Niro and Kea...
  </div>
  <div class='clearfix'></div>
</div>
EXPECTED
  end

  def expected_incomplete_result
    <<EXPECTED
<div class='onebox-result'>
    <div class='source'>
      <div class='info'>
        <a href='http://www.rottentomatoes.com/m/gunde_jaari_gallanthayyinde/' class="track-link" target="_blank">
          <img class='favicon' src="/assets/favicons/rottentomatoes.png"> rottentomatoes.com
        </a>
      </div>
    </div>
  <div class='onebox-result-body'>
    <img src="http://images.rottentomatoescdn.com/images/redesign/poster_default.gif" class="thumbnail">
    <h3><a href="http://www.rottentomatoes.com/m/gunde_jaari_gallanthayyinde/" target="_blank">Gunde Jaari Gallanthayyinde</a></h3>

    <b>Cast:</b> Nithin, Nithya Menon, Jwala Gutta<br />
    <b>Theater Release:</b> Apr 19, 2013<br />
    <b>Running Time:</b> 155 minutes<br />
    <b>Rated: </b> Unrated<br />
    Software engineer Karthik thinks he is the smartest guy on the earth, but he turns out be the biggest fool at the end.
  </div>
  <div class='clearfix'></div>
</div>
EXPECTED
  end
end

# encoding: utf-8

require 'spec_helper'
require 'oneboxer'
require 'oneboxer/amazon_onebox'

describe Oneboxer::AmazonOnebox do
  before(:each) do
    @o = Oneboxer::AmazonOnebox.new("http://www.amazon.com/Ruby-Programming-Language-David-Flanagan/dp/0596516177")
    FakeWeb.register_uri(:get, @o.translate_url, response: fixture_file('oneboxer/amazon.response'))
  end

  it "translates the URL" do
    @o.translate_url.should == "http://www.amazon.com/gp/aw/d/0596516177"
  end

  it "generates the expected onebox for Amazon" do
    @o.onebox.should match_html expected_amazon_result
  end

private
  def expected_amazon_result
    <<EXPECTED
<div class='onebox-result'>
    <div class='source'>
      <div class='info'>
        <a href='http://www.amazon.com/Ruby-Programming-Language-David-Flanagan/dp/0596516177' class="track-link" target="_blank">
          <img class='favicon' src="/assets/favicons/amazon.png"> amazon.com
        </a>
      </div>
    </div>
  <div class='onebox-result-body'>
    <img src="http://ecx.images-amazon.com/images/I/512Cx%2BnJK8L._BO2,204,203,200_PIsitb-sticker-arrow-click,TopRight,35,-76_AA300_SH20_OU01_.jpg" class="thumbnail">
    <h3><a href="http://www.amazon.com/Ruby-Programming-Language-David-Flanagan/dp/0596516177" target="_blank">The Ruby Programming Language [Paperback]</a></h3>


  </div>
  <div class='clearfix'></div>
</div>
EXPECTED
  end
end

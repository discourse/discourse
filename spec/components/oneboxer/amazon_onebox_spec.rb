# encoding: utf-8

require 'spec_helper'
require 'oneboxer'
require 'oneboxer/amazon_onebox'

describe Oneboxer::AmazonOnebox do 
  it "generates the expected onebox for Amazon" do
    o = Oneboxer::AmazonOnebox.new("http://www.amazon.com/Ruby-Programming-Language-David-Flanagan/dp/0596516177")
    o.onebox.should == expected_amazon_result
  end
  
private
  def expected_amazon_result
    <<EXPECTED
<div class='onebox-result'>
    <div class='source'>
      <div class='info'>
        <a href='http://www.amazon.com/Ruby-Programming-Language-David-Flanagan/dp/0596516177' target="_blank">
          <img class='favicon' src="/assets/favicons/amazon.png"> amazon.com
        </a>
      </div>
    </div>
  <div class='onebox-result-body'>
    <img src="http://ecx.images-amazon.com/images/I/716dULgyHNL._SY180_.jpg" class="thumbnail">
    <h3><a href="http://www.amazon.com/Ruby-Programming-Language-David-Flanagan/dp/0596516177" target="_blank">The Ruby Programming Language (Paperback)</a></h3>
    <h4>David Flanagan, Yukihiro Matsumoto</h4>
    
The Ruby Programming Language is the authoritative guide to Ruby&nbsp;...

  </div>
  <div class='clearfix'></div>
</div>
EXPECTED
  end
end
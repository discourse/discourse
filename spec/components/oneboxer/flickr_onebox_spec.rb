# encoding: utf-8

require 'spec_helper'
require 'oneboxer'
require 'oneboxer/flickr_onebox'

describe Oneboxer::FlickrOnebox do
  before(:each) do
    @o = Oneboxer::FlickrOnebox.new("http://www.flickr.com/photos/jaimeiniesta/3303881265")
    FakeWeb.register_uri(:get, @o.translate_url, response: fixture_file('oneboxer/flickr.response'))
  end

  it "generates the expected onebox for Flickr" do
    @o.onebox.should match_html expected_flickr_result
  end

private
  def expected_flickr_result
    "<a href='http://www.flickr.com/photos/jaimeiniesta/3303881265' target='_blank'><img src='http://farm4.staticflickr.com/3419/3303881265_c6924748e8_z.jpg' alt=''></a>"
  end
end

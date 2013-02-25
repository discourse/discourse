require 'spec_helper'
require 'oneboxer'
require 'oneboxer/gist_onebox'

describe Oneboxer::GistOnebox do
  it "does not trip on user names" do
    o = Oneboxer::GistOnebox.new('https://gist.github.com/aaa/4599619')
    o.translate_url.should == 'https://api.github.com/gists/4599619'
  end

  it "works for old school urls too" do
    o = Oneboxer::GistOnebox.new('https://gist.github.com/4599619')
    o.translate_url.should == 'https://api.github.com/gists/4599619'
  end
end


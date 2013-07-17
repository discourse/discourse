require 'spec_helper'

describe Discourse::Oneboxer::GistOnebox do
  it "does not trip on user names" do
    o = Discourse::Oneboxer::GistOnebox.new('https://gist.github.com/aaa/4599619')
    o.translate_url.should == 'https://api.github.com/gists/4599619'
  end

  it "works for old school urls too" do
    o = Discourse::Oneboxer::GistOnebox.new('https://gist.github.com/4599619')
    o.translate_url.should == 'https://api.github.com/gists/4599619'
  end
end


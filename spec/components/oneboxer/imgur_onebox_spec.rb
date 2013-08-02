# encoding: utf-8

require 'spec_helper'

describe Oneboxer::ImgurOnebox do
  it 'translates the URL which starts with gallery' do
    o = described_class.new("https://imgur.com/gallery/QvipVw4")
    expect(o.translate_url).to eq("http://api.imgur.com/2/image/QvipVw4.json")
  end
  it 'translates the URL which starts with the image hash' do
    o = described_class.new("https://imgur.com/QvipVw4")
    expect(o.translate_url).to eq("http://api.imgur.com/2/image/QvipVw4.json")
  end
end

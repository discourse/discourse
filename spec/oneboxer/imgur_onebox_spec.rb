require 'spec_helper'

describe Discourse::Oneboxer::ImgurOnebox do
  it 'translates the URL which starts with gallery' do
    o = described_class.new("https://imgur.com/gallery/QvipVw4")
    expect(o.translate_url).to eq("http://api.imgur.com/2/image/QvipVw4.json")
  end
  it 'translates the URL which starts with the image hash' do
    o = described_class.new("https://imgur.com/QvipVw4")
    expect(o.translate_url).to eq("http://api.imgur.com/2/image/QvipVw4.json")
  end
  it 'does not translate urls like the help page' do
    o = described_class.new("https://imgur.com/help")
    expect(o.translate_url).to be_nil
  end
  it 'does not translate urls of user pages' do
    o = described_class.new("http://imgur.com/user/a_user")
    expect(o.translate_url).to be_nil
  end

  it "should handle error responses properly"
end

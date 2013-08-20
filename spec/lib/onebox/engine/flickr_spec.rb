require "spec_helper"

describe Onebox::Engine::FlickrOnebox do
  let(:link) { "http://flickr.com" }
  let(:html) { described_class.new(link).to_html }

  before do
    fake(link, response("flickr.response"))
  end

  it "returns photo title" do
    expect(html).to include("Los Angeles View 2011")
  end

  it "returns photo" do
    expect(html).to include("6038315155_2875860c4b_z.jpg")
  end

  it "returns photo description" do
    expect(html).to include("The view from the Griffith Observatory, Los Angeles; July 2011")
  end

  it "returns URL" do
    expect(html).to include(link)
  end
end

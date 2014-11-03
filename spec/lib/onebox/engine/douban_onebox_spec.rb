require "spec_helper"

describe Onebox::Engine::DoubanOnebox do
  before(:all) do
    @link = "http://movie.douban.com/review/1503949/"
  end
  include_context "engines"
  it_behaves_like "an engine"

  before do
    fake(link, response("douban.response"))
  end

  it "has douban title" do
    expect(html).to include("那个荡气回肠的长镜头 (巴黎最后的探戈 影评)")
  end

  it "has douban image" do
    expect(html).to include("http://img3.douban.com/mpic/s2557510.jpg")
  end

  it "has the douban description" do
    expect(html).to include("<p>那个荡气回肠的长镜头")
  end

  it "has the URL to the resource" do
    expect(html).to include(link)
  end
end

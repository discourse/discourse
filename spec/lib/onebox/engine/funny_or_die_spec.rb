require "spec_helper"

describe Onebox::Engine::FunnyOrDieOnebox do
  let(:link) { "http://funnyordie.com" }
  let(:html) { described_class.new(link).to_html }

  before do
    fake(link, response("funnyordie.response"))
  end

  it "returns video title" do
    expect(html).to include("The Landlord")
  end

  # it "returns photo" do
  #   expect(html).to include("http://ib3.huluim.com/video/60245466?region=US&amp;size=600x400")
  # end

  it "returns video description" do
    expect(html).to include("Will Ferrell meets his landlord.")
  end

  # it "returns video URL" do
  #   expect(html).to include("https://secure.hulu.com/embed/0-us7uHJgevua5TeiGwCxQ")
  # end

  it "returns URL" do
    expect(html).to include(link)
  end
end

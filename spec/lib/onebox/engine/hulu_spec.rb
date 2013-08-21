require "spec_helper"

describe Onebox::Engine::HuluOnebox do
  let(:link) { "http://hulu.com" }
  let(:html) { described_class.new(link).to_html }

  before do
    fake(link, response("hulu.response"))
  end

  it "returns video title" do
    expect(html).to include("The Awesomes: Pilot, Part 1")
  end

  # it "returns photo" do
  #   expect(html).to include("6038315155_2875860c4b_z.jpg")
  # end

  # it "returns video description" do
  #   expect(html).to include("After Mr. Awesome decides to retire and disband The Awesomes")
  # end

  it "returns URL" do
    expect(html).to include(link)
  end
end

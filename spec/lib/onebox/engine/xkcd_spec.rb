# frozen_string_literal: true

RSpec.describe Onebox::Engine::XkcdOnebox do
  let(:link) { "https://xkcd.com/327/" }
  let(:api_link) { "https://xkcd.com/327/info.0.json" }
  let(:html) { described_class.new(link).to_html }

  before { stub_request(:get, api_link).to_return(status: 200, body: onebox_response("xkcd")) }

  it "has the comic's description" do
    expect(html).to include("Her daughter is named Help")
  end

  it "has the comic's title" do
    expect(html).to include("Exploits of a Mom")
  end

  it "has the permalink to the comic" do
    expect(html).to include(link)
  end

  it "has the comic image" do
    expect(html).to include("http://imgs.xkcd.com/comics/exploits_of_a_mom.png")
  end
end

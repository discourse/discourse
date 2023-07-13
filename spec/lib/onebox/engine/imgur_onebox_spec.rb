# frozen_string_literal: true

RSpec.describe Onebox::Engine::ImgurOnebox do
  let(:link) { "https://imgur.com/gallery/Sdc0Klc" }
  let(:imgur) { described_class.new(link) }
  let(:html) { imgur.to_html }

  before { stub_request(:get, link).to_return(status: 200, body: onebox_response("imgur")) }

  it "excludes html tags in title" do
    imgur.stubs(:is_album?).returns(true)
    expect(html).to include("<span class='album-title'>[Album] Did you miss me?</span>")
  end
end

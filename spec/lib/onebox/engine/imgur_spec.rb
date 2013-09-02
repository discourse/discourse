require "spec_helper"

describe Onebox::Engine::ImgurOnebox do
  let(:link) { "http://imgur.com" }
  let(:html) { described_class.new(link).to_html }

  before do
    fake(link, response("imgur.response"))
  end

  it "returns URL" do
    expect(html).to include(link)
  end
end

# frozen_string_literal: true

require "rails_helper"

describe Onebox::Engine::AnimatedImageOnebox do
  let(:giphy) { "http://gph.is/15bRbWf" }
  let(:tenor) { "https://tenor.com/bb3fQ.gif" }

  before do
    Onebox.options = { redirect_limit: 0 }
    stub_request(:get, giphy).to_return(status: 200, body: onebox_response("giphy"))
    stub_request(:get, tenor).to_return(status: 200, body: onebox_response("tenor"))
  end

  it "works for giphy short URLs" do
    html = described_class.new(giphy).to_html
    expect(html).to include("img")
    expect(html).to include("class='animated onebox'")
  end

  it "works for tenor URLs" do
    html = described_class.new(tenor).to_html
    expect(html).to include("img")
    expect(html).to include("class='animated onebox'")
  end
end

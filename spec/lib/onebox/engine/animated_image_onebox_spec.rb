# frozen_string_literal: true

require "rails_helper"

describe Onebox::Engine::AnimatedImageOnebox do
  let(:giphy) { "http://gph.is/15bRbWf" }
  let(:direct_gif) { "https://media4.giphy.com/media/Zatyu5LBO2zCyhiAAs/giphy.gif" }
  let(:tenor) { "https://tenor.com/bb3fQ.gif" }

  before do
    @previous_options = Onebox.options.to_h
    Onebox.options = { redirect_limit: 0 }
    stub_request(:get, giphy).to_return(status: 200, body: onebox_response("giphy"))
    stub_request(:get, direct_gif).to_return(status: 200, body: file_from_fixtures("animated.webp"))
    stub_request(:get, tenor).to_return(status: 200, body: onebox_response("tenor"))
  end

  after do
    Onebox.options = @previous_options
  end

  it "works for giphy short URLs" do
    html = described_class.new(giphy).to_html
    expect(html).to include("img")
    expect(html).to include("class='animated onebox'")
  end

  it "works when the response is the image asset itself" do
    html = described_class.new(direct_gif).to_html
    expect(html).to include("img")
    expect(html).to include("src='#{direct_gif}'")
    expect(html).to include("class='animated onebox'")
  end

  it "works for tenor URLs" do
    html = described_class.new(tenor).to_html
    expect(html).to include("img")
    expect(html).to include("class='animated onebox'")
  end
end

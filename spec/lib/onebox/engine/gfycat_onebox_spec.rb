# frozen_string_literal: true

require "rails_helper"

describe Onebox::Engine::GfycatOnebox do
  let(:link) { "https://gfycat.com/shrillnegativearrowana" }
  let(:html) { described_class.new(link).to_html }
  let(:placeholder_html) { described_class.new(link).placeholder_html }

  before do
    stub_request(:get, link).to_return(status: 200, body: onebox_response("gfycat"))
  end

  it "has the title" do
    expect(html).to include("shrillnegativearrowana")
    expect(placeholder_html).to include("shrillnegativearrowana")
  end

  it "has the link" do
    expect(html).to include(link)
    expect(placeholder_html).to include(link)
  end

  it "has the poster" do
    expect(html).to include("https://thumbs.gfycat.com/ShrillNegativeArrowana-poster.jpg")
  end

  it "has the webm video" do
    expect(html).to include("https://giant.gfycat.com/ShrillNegativeArrowana.webm")
  end

  it "has the mp4 video" do
    expect(html).to include("https://giant.gfycat.com/ShrillNegativeArrowana.mp4")
  end

  it "has keywords" do
    expect(html).to include("<a href='https://gfycat.com/gifs/search/lego'>#lego</a>")
  end
end

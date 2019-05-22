# frozen_string_literal: true

require "spec_helper"

describe Onebox::Engine::ImgurOnebox do
  let(:link) { "https://imgur.com/gallery/Sdc0Klc" }
  let(:imgur) { described_class.new(link) }
  let(:html) { imgur.to_html }

  before do
    fake(link, response("imgur"))
  end

  it "excludes html tags in title" do
    allow(imgur).to receive(:is_album?) { true }
    expect(html).to include("<span class='album-title'>[Album] Did you miss me?</span>")
  end
end

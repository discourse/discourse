# frozen_string_literal: true

require "spec_helper"

describe Onebox::Preview do

  before do
    fake("https://www.amazon.com/product", response("amazon"))
  end

  let(:preview_url) { "http://www.amazon.com/product" }
  let(:preview) { described_class.new(preview_url) }

  describe "#to_s" do
    it "returns some html if given a valid url" do
      title = "Seven Languages in Seven Weeks: A Pragmatic Guide to Learning Programming Languages (Pragmatic Programmers)"
      expect(preview.to_s).to include(title)
    end

    it "returns an empty string if the url is not valid" do
      expect(described_class.new('not a url').to_s).to eq("")
    end
  end

  describe "max_width" do
    let(:iframe_html) { '<iframe src="//player.vimeo.com/video/96017582" width="1280" height="720" frameborder="0" title="GO BIG OR GO HOME" webkitallowfullscreen mozallowfullscreen allowfullscreen></iframe>' }

    it "doesn't change dimensions without an option" do
      iframe = described_class.new(preview_url)
      allow(iframe).to receive(:engine_html) { iframe_html }

      result = iframe.to_s
      expect(result).to include("width=\"1280\"")
      expect(result).to include("height=\"720\"")
    end

    it "doesn't change dimensions if it is smaller than `max_width`" do
      iframe = described_class.new(preview_url, max_width: 2000)
      allow(iframe).to receive(:engine_html) { iframe_html }

      result = iframe.to_s
      expect(result).to include("width=\"1280\"")
      expect(result).to include("height=\"720\"")
    end

    it "changes dimensions if larger than `max_width`" do
      iframe = described_class.new(preview_url, max_width: 900)
      allow(iframe).to receive(:engine_html) { iframe_html }

      result = iframe.to_s
      expect(result).to include("width=\"900\"")
      expect(result).to include("height=\"506\"")
    end
  end

  describe "#engine" do
    it "returns an engine" do
      expect(preview.send(:engine)).to be_an(Onebox::Engine)
    end
  end

  describe "xss" do
    let(:xss) { "wat' onerror='alert(/XSS/)" }
    let(:img_html) { "<img src='#{xss}'>" }

    it "prevents XSS" do
      preview = described_class.new(preview_url)
      allow(preview).to receive(:engine_html) { img_html }

      result = preview.to_s
      expect(result).not_to match(/onerror/)
    end

  end

end

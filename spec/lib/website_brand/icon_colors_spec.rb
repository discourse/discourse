# frozen_string_literal: true

RSpec.describe WebsiteBrand::IconColors do
  describe ".call" do
    it "counts the colors in an SVG icon" do
      svg = <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">
          <style>.mark { fill: #e8590c; }</style>
          <rect class="mark" width="10" height="10" fill="#E8590C"/>
          <path style="stroke: rgb(0, 102, 204)" d="M0 0"/>
          <circle fill="none" r="2"/>
        </svg>
      SVG

      expect(described_class.call(svg)).to eq("e8590c" => 2, "0066cc" => 1)
    end

    it "doesn't load external entities in an SVG icon" do
      Tempfile.create(%w[website-brand-entity .txt]) do |file|
        file.write("#e8590c")
        file.flush
        svg = <<~SVG
          <?xml version="1.0"?>
          <!DOCTYPE svg [<!ENTITY color SYSTEM "file://#{file.path}">]>
          <svg xmlns="http://www.w3.org/2000/svg"><rect fill="&color;"/></svg>
        SVG

        expect(described_class.call(svg)).to eq({})
      end
    end

    it "counts the colors in a raster icon" do
      png = File.binread(Rails.root.join("spec/fixtures/images/website_brand_icon.png"))

      expect(described_class.call(png)).to eq("e8590c" => 4096)
    end

    it "returns no colors for a file it can't read" do
      expect(described_class.call("not an icon")).to eq({})
      expect(described_class.call("\x89PNG\r\n\x1A\nbroken".b)).to eq({})
    end
  end
end

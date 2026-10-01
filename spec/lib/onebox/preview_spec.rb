# frozen_string_literal: true

RSpec.describe Onebox::Preview do
  before do
    stub_request(:get, "https://www.amazon.com/product").to_return(
      status: 200,
      body: onebox_response("amazon"),
    )
  end

  let(:preview_url) { "http://www.amazon.com/product" }
  let(:preview) { described_class.new(preview_url) }

  describe "#to_s" do
    before do
      stub_request(
        :get,
        "https://www.amazon.com/Seven-Languages-Weeks-Programming-Programmers/dp/193435659X",
      ).to_return(status: 200, body: onebox_response("amazon"))
    end

    it "returns some html if given a valid url" do
      title =
        "Seven Languages in Seven Weeks: A Pragmatic Guide to Learning Programming Languages (Pragmatic Programmers)"
      expect(preview.to_s).to include(title)
    end

    it "returns an empty string if the url is not valid" do
      expect(described_class.new("not a url").to_s).to eq("")
    end

    it "omits loopback, private, and local-hostname images from Discourse oneboxes" do
      preview =
        described_class.new(preview_url, sanitize_config: Onebox::SanitizeConfig::DISCOURSE_ONEBOX)
      preview.stubs(:engine_html).returns(<<~HTML)
        <img src="http://127.0.0.1/a.png">
        <img src="http://192.168.1.1/a.png">
        <img src="http://[::1]/a.png">
        <img src="http://2130706433/a.png">
        <img src="http://127.0.0.%31/a.png">
        <img src="http://%31%32%37.0.0.1/a.png">
        <img src="http://printer.local/a.png">
        <img src="http://localhost/a.png">
        <img src="https://cdn.example.com/a.png">
      HTML

      images = Nokogiri::HTML5.fragment(preview.to_s).css("img")

      expect(images.filter_map { |image| image["src"] }).to eq(["https://cdn.example.com/a.png"])
    end

    it "omits local URLs in other automatically loaded media attributes" do
      preview =
        described_class.new(
          preview_url,
          sanitize_config: Onebox::SanitizeConfig::DISCOURSE_ONEBOX,
          allowed_iframe_origins: ["http://127.0.0.1"],
        )
      preview.stubs(:engine_html).returns(<<~HTML)
        <img src="https://cdn.example.com/a.png" srcset="https://cdn.example.com/a.png 1x, http://127.0.0.1/b.png 2x">
        <video poster="http://127.0.0.1/a.png"><source src="http://10.0.0.1/a.mp4"></video>
        <iframe src="http://127.0.0.1/a"></iframe>
        <span style="background-image: url(http://127.0.0.1/a.png)">Text</span>
      HTML

      output = Nokogiri::HTML5.fragment(preview.to_s)

      expect(output.at_css("img")["src"]).to eq("https://cdn.example.com/a.png")
      expect(output.at_css("img")["srcset"]).to be_nil
      expect(output.at_css("video")["poster"]).to be_nil
      expect(output.at_css("source")["src"]).to be_nil
      expect(output.at_css("iframe")["src"]).to be_nil
      expect(output.at_css("span")["style"]).to be_nil
    end

    it "retains relative and own-site image URLs" do
      preview =
        described_class.new(preview_url, sanitize_config: Onebox::SanitizeConfig::DISCOURSE_ONEBOX)
      own_image_url = "#{Discourse.base_url_no_prefix}/uploads/image.png"
      preview.stubs(:engine_html).returns(<<~HTML)
        <img src="/uploads/image.png">
        <img src="#{own_image_url}">
      HTML

      images = Nokogiri::HTML5.fragment(preview.to_s).css("img")

      expect(images.filter_map { |image| image["src"] }).to eq(
        ["/uploads/image.png", own_image_url],
      )
    end
  end

  describe "max_width" do
    let(:iframe_html) do
      '<iframe src="//player.vimeo.com/video/96017582" width="1280" height="720" frameborder="0" title="GO BIG OR GO HOME" webkitallowfullscreen mozallowfullscreen allowfullscreen></iframe>'
    end

    it "doesn't change dimensions without an option" do
      iframe = described_class.new(preview_url)
      iframe.stubs(:engine_html).returns(iframe_html)

      result = iframe.to_s
      expect(result).to include("width=\"1280\"")
      expect(result).to include("height=\"720\"")
    end

    it "doesn't change dimensions if it is smaller than `max_width`" do
      iframe = described_class.new(preview_url, max_width: 2000)
      iframe.stubs(:engine_html).returns(iframe_html)

      result = iframe.to_s
      expect(result).to include("width=\"1280\"")
      expect(result).to include("height=\"720\"")
    end

    it "changes dimensions if larger than `max_width`" do
      iframe = described_class.new(preview_url, max_width: 900)
      iframe.stubs(:engine_html).returns(iframe_html)

      result = iframe.to_s
      expect(result).to include("width=\"900\"")
      expect(result).to include("height=\"506\"")
    end
  end

  describe "#engine" do
    let(:preview_image_url) { "http://www.example.com/image/without/file_extension" }
    let(:preview_image) { described_class.new(preview_image_url, content_type: "image/png") }

    it "returns an engine" do
      expect(preview.send(:engine)).to be_an(Onebox::Engine)
    end

    it "can match based on content_type" do
      expect(preview_image.send(:engine)).to be_an(Onebox::Engine::ImageOnebox)
    end
  end

  describe "xss" do
    let(:xss) { "wat' onerror='alert(/XSS/)" }
    let(:img_html) { "<img src='#{xss}'>" }

    it "prevents XSS" do
      preview = described_class.new(preview_url)
      preview.stubs(:engine_html).returns(img_html)

      result = preview.to_s
      expect(result).not_to match(/onerror/)
    end
  end

  describe "iframe sanitizer" do
    let(:iframe_html) { "<iframe src='https://thirdparty.example.com'>" }

    it "sanitizes iframes from unknown origins" do
      preview = described_class.new(preview_url)
      preview.stubs(:engine_html).returns(iframe_html)

      result = preview.to_s
      expect(result).not_to include(' src="https://thirdparty.example.com"')
      expect(result).to include(' data-unsanitized-src="https://thirdparty.example.com"')
    end

    it "allows allowed origins" do
      preview =
        described_class.new(preview_url, allowed_iframe_origins: ["https://thirdparty.example.com"])
      preview.stubs(:engine_html).returns(iframe_html)

      result = preview.to_s
      expect(result).to include ' src="https://thirdparty.example.com"'
    end

    it "allows wildcard allowed origins" do
      preview = described_class.new(preview_url, allowed_iframe_origins: ["https://*.example.com"])
      preview.stubs(:engine_html).returns(iframe_html)

      result = preview.to_s
      expect(result).to include ' src="https://thirdparty.example.com"'
    end
  end

  describe "svg sanitization" do
    it "does not allow unexpected elements inside svg" do
      preview = described_class.new(preview_url)
      preview.stubs(:engine_html).returns <<~HTML.strip
        <svg><style>/*Text*/</style></svg>
      HTML

      result = preview.to_s
      expect(result).to eq("<svg></svg>")
    end

    it "does not allow text inside svg" do
      preview = described_class.new(preview_url)
      preview.stubs(:engine_html).returns <<~HTML.strip
        <svg>Hello world</svg>
      HTML

      result = preview.to_s
      expect(result).to eq("<svg></svg>")
    end

    it "allows simple svg" do
      simple_svg =
        '<svg height="210" width="400"><path d="M150 5 L75 200 L225 200 Z" style="fill:none;stroke:green;stroke-width:3"></path></svg>'
      preview = described_class.new(preview_url)
      preview.stubs(:engine_html).returns simple_svg

      result = preview.to_s
      expect(result).to eq(simple_svg)
    end
  end
end

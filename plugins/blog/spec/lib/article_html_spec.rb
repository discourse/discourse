# frozen_string_literal: true

RSpec.describe Blog::ArticleHtml do
  describe ".render" do
    before { set_cdn_url("https://cdn.example.com") }

    it "makes root-relative links and media absolute" do
      html = described_class.render(<<~HTML)
        <a href="/t/topic/1">Topic</a>
        <a href="#footnote">Footnote</a>
        <a href="//elsewhere.example.com/page">Elsewhere</a>
        <img src="/uploads/image.png" srcset="/uploads/image.png 1x, /uploads/image@2x.png 2x">
        <video poster="/uploads/poster.png"></video>
        <div class="spoiler">Hidden</div>
      HTML
      document = Nokogiri::HTML5.fragment(html)

      expect(html).to be_html_safe
      expect(document.css("a").map { |link| link["href"] }).to eq(
        %w[http://test.localhost/t/topic/1 #footnote //elsewhere.example.com/page],
      )
      expect(document.at_css("img")["src"]).to eq("https://cdn.example.com/uploads/image.png")
      expect(document.at_css("img")["srcset"]).to eq(
        "https://cdn.example.com/uploads/image.png 1x, https://cdn.example.com/uploads/image@2x.png 2x",
      )
      expect(document.at_css("video")["poster"]).to eq("https://cdn.example.com/uploads/poster.png")
      expect(document.at_css(".spoiler")["tabindex"]).to eq("0")
    end

    it "renders nothing without cooked HTML" do
      expect(described_class.render(nil)).to eq("")
    end
  end
end

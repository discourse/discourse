# frozen_string_literal: true

RSpec.describe Onebox::Engine::StandardEmbed do
  let(:host_class) do
    Class.new do
      include Onebox::Engine::StandardEmbed

      def options
        {}
      end

      def url
        ""
      end
    end
  end
  let(:instance) { host_class.new }

  describe "#raw" do
    it "does not set title_attr from opengraph data" do
      Onebox::Helpers.stubs(fetch_html_doc: nil)
      Onebox::OpenGraph
        .any_instance
        .stubs(:data)
        .returns({ description: "description", title_attr: "should not be returned" })
      Onebox::Oembed.any_instance.stubs(:data).returns({})

      expect(instance.raw).to eq({ description: "description" })
    end

    it "sets twitter data" do
      html_doc = mocked_html_doc(twitter_data: { "name" => "twitter:url", "content" => "cool.url" })
      Onebox::Helpers.stubs(fetch_html_doc: html_doc)

      expect(instance.raw).to eq({ url: "cool.url" })
    end

    it "does not override data with twitter data" do
      html_doc =
        mocked_html_doc(
          twitter_data: {
            "name" => "twitter:title",
            "content" => "i do not want to override",
          },
        )
      Onebox::OpenGraph
        .any_instance
        .stubs(:data)
        .returns({ description: "description", title: "do not override me" })
      Onebox::Helpers.stubs(fetch_html_doc: html_doc)

      expect(instance.raw).to eq({ description: "description", title: "do not override me" })
    end

    it "does not override data with oembed data" do
      Onebox::Oembed.any_instance.stubs(:data).returns({ title: "i do not want to override" })
      html_doc =
        mocked_html_doc(
          twitter_data: {
            "name" => "twitter:title",
            "content" => "do not override me",
          },
        )
      Onebox::Helpers.stubs(fetch_html_doc: html_doc)

      expect(instance.raw).to eq({ title: "do not override me" })
    end

    it "sets favicon URL" do
      html_doc =
        mocked_html_doc(
          twitter_data: {
            "name" => "twitter:url",
            "content" => "cool.url",
          },
          favicon_url: "https://favicon.co/default.ico",
        )
      Onebox::Helpers.stubs(fetch_html_doc: html_doc)

      expect(instance.raw).to eq({ url: "cool.url", favicon: "https://favicon.co/default.ico" })
    end

    it "ignores suspiciously long favicon URLs" do
      html_doc =
        mocked_html_doc(
          twitter_data: {
            "name" => "twitter:url",
            "content" => "cool.url",
          },
          favicon_url: "https://favicon.co/#{"a" * 2_000}.ico",
        )
      Onebox::Helpers.stubs(fetch_html_doc: html_doc)

      expect(instance.raw).to eq({ url: "cool.url" })
    end

    it "sets oembed data" do
      Onebox::Helpers.stubs(fetch_html_doc: nil)
      Onebox::Oembed.any_instance.stubs(:data).returns({ description: "description" })

      expect(instance.raw).to eq({ description: "description" })
    end

    it "skips oembed dimensions for rich embeds" do
      Onebox::Helpers.stubs(fetch_html_doc: nil)
      Onebox::Oembed
        .any_instance
        .stubs(:data)
        .returns({ type: "rich", width: 600, height: 338, title: "Title" })

      expect(instance.raw).to eq({ type: "rich", title: "Title" })
    end

    it "does not override data with json_ld data" do
      Onebox::Helpers.stubs(fetch_html_doc: nil)
      Onebox::JsonLd.any_instance.stubs(:data).returns({ title: "i do not want to override" })
      Onebox::Oembed.any_instance.stubs(:data).returns({ title: "do not override me" })

      expect(instance.raw).to eq({ title: "do not override me" })
    end
  end

  describe "anchor enhancement" do
    let(:anchor_class) do
      Class.new do
        include Onebox::Engine::StandardEmbed

        attr_accessor :url, :options, :html_doc_override

        def initialize(url)
          @url = url
          @options = {}
        end

        def html_doc
          @html_doc_override
        end
      end
    end

    def embed_with_html(url, html, raw = {})
      embed = anchor_class.new(url)
      embed.html_doc_override = Nokogiri.HTML(html)
      embed.instance_variable_set(:@raw, raw)
      embed
    end

    describe "#enhance_title_with_anchor" do
      it "prepends section title from heading with matching ID" do
        html = "<h2 id='setup'>Setup</h2>"
        embed = embed_with_html("https://x.com#setup", html, { title: "Docs" })
        embed.send(:enhance_title_with_anchor)
        expect(embed.instance_variable_get(:@raw)[:title]).to eq("Setup - Docs")
      end

      it "finds title from code element within target" do
        html = "<div id='fn'><code>foo()</code></div>"
        embed = embed_with_html("https://x.com#fn", html, { title: "API" })
        embed.send(:enhance_title_with_anchor)
        expect(embed.instance_variable_get(:@raw)[:title]).to eq("foo() - API")
      end

      it "finds target by a[name] attribute" do
        html = "<h2>Legacy Section</h2><a name='legacy'></a><p>Content</p>"
        embed = embed_with_html("https://x.com#legacy", html, { title: "Docs" })
        embed.send(:enhance_title_with_anchor)
        expect(embed.instance_variable_get(:@raw)[:title]).to eq("Legacy Section - Docs")
      end

      it "does not duplicate when section title already in page title" do
        html = "<h2 id='install'>Install</h2>"
        embed = embed_with_html("https://x.com#install", html, { title: "Install Guide" })
        embed.send(:enhance_title_with_anchor)
        expect(embed.instance_variable_get(:@raw)[:title]).to eq("Install Guide")
      end

      it "URL-decodes fragments" do
        html = "<div id='Foo{Bar}'><code>Foo</code></div>"
        embed = embed_with_html("https://x.com#Foo%7BBar%7D", html, { title: "Docs" })
        embed.send(:enhance_title_with_anchor)
        expect(embed.instance_variable_get(:@raw)[:title]).to eq("Foo - Docs")
      end

      it "cleans pilcrow, section mark, and hash from titles" do
        embed = anchor_class.new("https://x.com#x")
        expect(embed.send(:clean_section_title, "Title ¶ § #")).to eq("Title")
      end

      it "truncates titles to 80 chars" do
        embed = anchor_class.new("https://x.com#x")
        expect(embed.send(:clean_section_title, "A" * 100).length).to be <= 80
      end

      it "handles anchors with no nearby heading" do
        html = "<span id='orphan'>text</span>"
        embed = embed_with_html("https://x.com#orphan", html, { title: "Page" })
        embed.send(:enhance_title_with_anchor)
        expect(embed.instance_variable_get(:@raw)[:title]).to eq("Page")
      end

      it "does nothing without fragment" do
        embed = embed_with_html("https://x.com", "<h2 id='x'>X</h2>", { title: "Page" })
        embed.send(:enhance_title_with_anchor)
        expect(embed.instance_variable_get(:@raw)[:title]).to eq("Page")
      end
    end

    describe "#enhance_description_with_anchor" do
      it "prepends section description to existing description" do
        html = "<article><div id='fn'><p>Does something.</p></div></article>"
        embed = embed_with_html("https://x.com#fn", html, { description: "Generic." })
        embed.send(:enhance_description_with_anchor)
        expect(embed.instance_variable_get(:@raw)[:description]).to eq("Does something. | Generic.")
      end

      it "sets description when none exists" do
        html = "<section id='intro'><p>Welcome.</p></section>"
        embed = embed_with_html("https://x.com#intro", html, {})
        embed.send(:enhance_description_with_anchor)
        expect(embed.instance_variable_get(:@raw)[:description]).to eq("Welcome.")
      end

      it "finds paragraph following anchor element" do
        html = "<h2 id='feat'>Features</h2><p>Great features.</p>"
        embed = embed_with_html("https://x.com#feat", html, {})
        embed.send(:enhance_description_with_anchor)
        expect(embed.instance_variable_get(:@raw)[:description]).to eq("Great features.")
      end

      it "extracts from nested docstring structure" do
        html =
          "<details class='docstring'><summary id='fn'></summary><p>Returns value.</p></details>"
        embed = embed_with_html("https://x.com#fn", html, { description: "Docs." })
        embed.send(:enhance_description_with_anchor)
        expect(embed.instance_variable_get(:@raw)[:description]).to eq("Returns value. | Docs.")
      end

      it "does not duplicate when section text already in description" do
        html = "<div id='x'><p>Same text.</p></div>"
        embed = embed_with_html("https://x.com#x", html, { description: "Same text." })
        embed.send(:enhance_description_with_anchor)
        expect(embed.instance_variable_get(:@raw)[:description]).to eq("Same text.")
      end

      it "truncates to 300 chars with ellipsis" do
        html = "<div id='x'><p>#{"A" * 400}</p></div>"
        embed = embed_with_html("https://x.com#x", html, {})
        embed.send(:enhance_description_with_anchor)
        desc = embed.instance_variable_get(:@raw)[:description]
        expect(desc.length).to be <= 301
        expect(desc).to end_with("…")
      end

      it "normalizes whitespace" do
        html = "<div id='x'><p>Line one.\n\n   Line two.</p></div>"
        embed = embed_with_html("https://x.com#x", html, {})
        embed.send(:enhance_description_with_anchor)
        expect(embed.instance_variable_get(:@raw)[:description]).to eq("Line one. Line two.")
      end
    end
  end

  private

  def mocked_html_doc(twitter_data: nil, favicon_url: nil)
    html_doc = mock
    html_doc.stubs(at_css: nil, at: nil)
    stub_twitter(html_doc, twitter_data)
    stub_favicon(html_doc, favicon_url)
    stub_json_ld
    html_doc
  end

  def stub_twitter(html_doc, twitter_data = [])
    html_doc.expects(:css).with("meta").at_least_once.returns([twitter_data])
  end

  def stub_favicon(html_doc, favicon_url = nil)
    html_doc
      .stubs(:css)
      .with(
        'link[rel="shortcut icon"], link[rel="icon shortcut"], link[rel="shortcut"], link[rel="icon"]',
      )
      .returns([{ "href" => favicon_url }.compact])
  end

  def stub_json_ld
    normalizer = mock
    normalizer.stubs(:data).returns([])
    Onebox::JsonLd.stubs(new: normalizer)
  end
end

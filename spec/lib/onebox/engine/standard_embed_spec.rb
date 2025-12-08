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

    it "does not override data with json_ld data" do
      Onebox::Helpers.stubs(fetch_html_doc: nil)
      Onebox::JsonLd.any_instance.stubs(:data).returns({ title: "i do not want to override" })
      Onebox::Oembed.any_instance.stubs(:data).returns({ title: "do not override me" })

      expect(instance.raw).to eq({ title: "do not override me" })
    end
  end

  describe "#enhance_title_with_anchor" do
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

    it "extracts fragment from URL" do
      embed = anchor_class.new("https://example.com/page#my-section")
      expect(embed.send(:extract_url_fragment)).to eq("my-section")
    end

    it "URL-decodes the fragment" do
      embed = anchor_class.new("https://example.com/page#Base.pkgversion-Tuple%7BModule%7D")
      expect(embed.send(:extract_url_fragment)).to eq("Base.pkgversion-Tuple{Module}")
    end

    it "returns nil for URLs without fragments" do
      embed = anchor_class.new("https://example.com/page")
      expect(embed.send(:extract_url_fragment)).to be_nil
    end

    it "finds section title from heading element with matching ID" do
      html = <<~HTML
        <html><body>
          <h2 id="my-section">My Section Title</h2>
          <p>Content here</p>
        </body></html>
      HTML
      embed = anchor_class.new("https://example.com/page#my-section")
      embed.html_doc_override = Nokogiri::HTML(html)

      expect(embed.send(:find_section_title, "my-section")).to eq("My Section Title")
    end

    it "finds section title from code element within target" do
      html = <<~HTML
        <html><body>
          <div id="Base.pkgversion-Tuple{Module}">
            <code>pkgversion(m::Module)</code>
            <p>Returns the version of the package.</p>
          </div>
        </body></html>
      HTML
      embed = anchor_class.new("https://example.com/page#Base.pkgversion-Tuple{Module}")
      embed.html_doc_override = Nokogiri::HTML(html)

      expect(embed.send(:find_section_title, "Base.pkgversion-Tuple{Module}")).to eq("pkgversion(m::Module)")
    end

    it "does not duplicate title when section title already appears in page title" do
      html = <<~HTML
        <html><body>
          <h2 id="installation">Installation</h2>
        </body></html>
      HTML
      embed = anchor_class.new("https://example.com/page#installation")
      embed.html_doc_override = Nokogiri::HTML(html)
      embed.instance_variable_set(:@raw, { title: "Installation Guide - My Project" })

      embed.send(:enhance_title_with_anchor)

      expect(embed.instance_variable_get(:@raw)[:title]).to eq("Installation Guide - My Project")
    end

    it "prepends section title to page title" do
      html = <<~HTML
        <html><body>
          <h2 id="getting-started">Getting Started</h2>
        </body></html>
      HTML
      embed = anchor_class.new("https://example.com/page#getting-started")
      embed.html_doc_override = Nokogiri::HTML(html)
      embed.instance_variable_set(:@raw, { title: "My Project Documentation" })

      embed.send(:enhance_title_with_anchor)

      expect(embed.instance_variable_get(:@raw)[:title]).to eq("Getting Started - My Project Documentation")
    end

    it "cleans anchor symbols from section titles" do
      embed = anchor_class.new("https://example.com/page#test")
      expect(embed.send(:clean_section_title, "My Section ¶")).to eq("My Section")
      expect(embed.send(:clean_section_title, "Another § Section")).to eq("Another Section")
      expect(embed.send(:clean_section_title, "Title #")).to eq("Title")
    end

    it "truncates long section titles" do
      embed = anchor_class.new("https://example.com/page#test")
      long_title = "A" * 100
      result = embed.send(:clean_section_title, long_title)
      expect(result.length).to be <= 80
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

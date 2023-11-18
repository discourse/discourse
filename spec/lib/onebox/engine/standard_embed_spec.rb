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

# frozen_string_literal: true

RSpec.describe Onebox::Layout do
  let(:record) { {} }
  let(:layout) { described_class.new("amazon", record) }
  let(:html) { layout.to_html }

  describe "#to_html" do
    it "contains layout template" do
      expect(html).to include(%|class="onebox|)
    end

    it "contains the view" do
      record = { link: "foo" }
      html = described_class.new("amazon", record).to_html
      expect(html).to include(%|"foo"|)
    end

    it "rewrites relative image path" do
      record = { image: "/image.png", link: "https://discourse.org" }
      klass = described_class.new("allowlistedgeneric", record)
      expect(klass.view.record[:image]).to include("https://discourse.org")
    end

    it "uses a matching header template in place of the default source header" do
      Dir.mktmpdir do |directory|
        original_options = Onebox.options.to_h
        File.write(
          File.join(directory, "amazon_header.mustache"),
          '<header class="custom-header">{{title}}</header>',
        )
        Onebox.options =
          original_options.merge(load_paths: original_options[:load_paths] + [directory])

        preview =
          Nokogiri::HTML5.fragment(
            described_class.new(
              "amazon",
              { link: "https://example.com", title: "Custom <header>" },
            ).to_html,
          )

        expect(preview.css("aside > header").size).to eq(1)
        expect(preview.at_css(".custom-header").text).to eq("Custom <header>")
        expect(preview.at_css(".source")).to be_nil
        expect(preview.at_css(".onebox-body")).to be_present
      ensure
        Onebox.options = original_options
      end
    end

    it "keeps the default source header when there is no matching header template" do
      preview =
        Nokogiri::HTML5.fragment(
          described_class.new(
            "amazon",
            { link: "https://example.com", favicon: "https://example.com/favicon.png" },
          ).to_html,
        )

      expect(preview.css("aside > header").size).to eq(1)
      expect(preview.at_css(".source a").text).to eq("example.com")
      expect(preview.at_css(".source .site-icon")["src"]).to eq("https://example.com/favicon.png")
    end
  end
end

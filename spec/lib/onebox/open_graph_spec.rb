# frozen_string_literal: true

require "onebox/open_graph"

RSpec.describe Onebox::OpenGraph do
  it "excludes html tags in title" do
    doc =
      Nokogiri.HTML(
        '<html><title>Did&#8217; you &lt;b&gt;miss me&lt;/b&gt;? - Album on Imgur</title><meta name="og:description" content="Post with 7 votes and 151 views. Shared by vinothkannans. Did you &lt;b&gt;miss me&lt;/b&gt;?" /><meta property="og:image" content="https://i.imgur.com/j1CNCZY.gif?noredirect" /></html>',
      )
    og = described_class.new(doc)
    expect(og.title).to eq("Did’ you miss me? - Album on Imgur")
    expect(og.description).to eq(
      "Post with 7 votes and 151 views. Shared by vinothkannans. Did you miss me?",
    )
    expect(og.image).to eq("https://i.imgur.com/j1CNCZY.gif?noredirect")
  end

  it "correctly normalizes the url properties" do
    doc =
      Nokogiri.HTML(
        "<html><meta property=\"og:image\" content=\"http://test.com/test'ing.mp3\" /></html>",
      )
    og = described_class.new(doc)
    expect(og.image).to eq("http://test.com/test&apos;ing.mp3")
  end

  describe "Collections" do
    subject(:graph) { described_class.new(doc) }

    let(:doc) { Nokogiri.HTML(<<-HTML) }
      <html>
        <title>test</title>
        <meta property="og:article:tag" content="&lt;b&gt;tag1&lt;/b&gt;" />
        <meta property="og:article:tag" content="tag2" />
        <meta property="og:article:section" content="category1" />
        <meta property="og:article:section" content="category2" />
        <meta property="og:article:section:color" content="ff0000" />
        <meta property="og:article:section:color" content="0000ff" />
      </html>
      HTML

    it "handles multiple article:tag tags" do
      expect(graph.article_tags).to eq %w[tag1 tag2]
    end

    it "handles multiple article:section tags" do
      expect(graph.article_sections).to eq %w[category1 category2]
    end

    it "handles multiple article:section:color tags" do
      expect(graph.article_section_colors).to eq %w[ff0000 0000ff]
    end
  end
end

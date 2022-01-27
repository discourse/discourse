# frozen_string_literal: true

require "rails_helper"
require "onebox/open_graph"

describe Onebox::OpenGraph do
  it "excludes html tags in title" do
    doc = Nokogiri::HTML('<html><title>Did&#8217; you &lt;b&gt;miss me&lt;/b&gt;? - Album on Imgur</title><meta name="og:description" content="Post with 7 votes and 151 views. Shared by vinothkannans. Did you &lt;b&gt;miss me&lt;/b&gt;?" /><meta property="og:image" content="https://i.imgur.com/j1CNCZY.gif?noredirect" /></html>')
    og = described_class.new(doc)
    expect(og.title).to eq("Did’ you miss me? - Album on Imgur")
    expect(og.description).to eq("Post with 7 votes and 151 views. Shared by vinothkannans. Did you miss me?")
    expect(og.image).to eq("https://i.imgur.com/j1CNCZY.gif?noredirect")
  end

  it "correctly normalizes the url properties" do
    doc = Nokogiri::HTML("<html><meta property=\"og:image\" content=\"http://test.com/test'ing.mp3\" /></html>")
    og = described_class.new(doc)
    expect(og.image).to eq("http://test.com/test&apos;ing.mp3")
  end
end

require 'rails_helper'
require_dependency 'inline_oneboxer'

describe InlineOneboxer do

  it "should return nothing with empty input" do
    expect(InlineOneboxer.new([]).process).to be_blank
  end

  it "can onebox a topic" do
    topic = Fabricate(:topic)
    results = InlineOneboxer.new([topic.url], skip_cache: true).process
    expect(results).to be_present
    expect(results[0][:url]).to eq(topic.url)
    expect(results[0][:title]).to eq(topic.title)
  end

  it "doesn't onebox private messages" do
    topic = Fabricate(:private_message_topic)
    results = InlineOneboxer.new([topic.url], skip_cache: true).process
    expect(results).to be_blank
  end

  context "caching" do
    let(:topic) { Fabricate(:topic) }

    before do
      InlineOneboxer.purge(topic.url)
    end

    it "puts an entry in the cache" do
      expect(InlineOneboxer.cache_lookup(topic.url)).to be_blank

      result = InlineOneboxer.lookup(topic.url)
      expect(result).to be_present

      cached = InlineOneboxer.cache_lookup(topic.url)
      expect(cached[:url]).to eq(topic.url)
      expect(cached[:title]).to eq(topic.title)
    end

    it "puts an entry in the cache for failed onebox" do
      SiteSetting.enable_inline_onebox_on_all_domains = true
      url = "https://example.com/random-url"

      InlineOneboxer.purge(url)
      expect(InlineOneboxer.cache_lookup(url)).to be_blank

      result = InlineOneboxer.lookup(url)
      expect(result).to be_present

      cached = InlineOneboxer.cache_lookup(url)
      expect(cached[:url]).to eq(url)
      expect(cached[:title]).to be_nil
    end
  end

  context ".lookup" do
    it "can lookup one link at a time" do
      topic = Fabricate(:topic)
      onebox = InlineOneboxer.lookup(topic.url, skip_cache: true)
      expect(onebox).to be_present
      expect(onebox[:url]).to eq(topic.url)
      expect(onebox[:title]).to eq(topic.title)
    end

    it "returns nothing for unknown links" do
      expect(InlineOneboxer.lookup(nil)).to be_nil
      expect(InlineOneboxer.lookup("/test")).to be_nil
    end

    it "will return the fancy title" do
      topic = Fabricate(:topic, title: "Hello :pizza: with an emoji")
      onebox = InlineOneboxer.lookup(topic.url, skip_cache: true)
      expect(onebox).to be_present
      expect(onebox[:url]).to eq(topic.url)
      expect(onebox[:title]).to eq("Hello 🍕 with an emoji")
    end

    it "will not crawl domains that aren't whitelisted" do
      onebox = InlineOneboxer.lookup("https://eviltrout.com", skip_cache: true)
      expect(onebox).to be_blank
    end

    it "will crawl anything if allowed to" do
      SiteSetting.enable_inline_onebox_on_all_domains = true

      stub_request(:get, "https://eviltrout.com/some-path").
        to_return(status: 200, body: "<html><head><title>a blog</title></head></html>")

      onebox = InlineOneboxer.lookup(
        "https://eviltrout.com/some-path",
        skip_cache: true
      )

      expect(onebox).to be_present
      expect(onebox[:url]).to eq("https://eviltrout.com/some-path")
      expect(onebox[:title]).to eq("a blog")
    end

    it "will not return a onebox if it does not meet minimal length" do
      SiteSetting.enable_inline_onebox_on_all_domains = true

      stub_request(:get, "https://eviltrout.com/some-path").
        to_return(status: 200, body: "<html><head><title>a</title></head></html>")

      onebox = InlineOneboxer.lookup(
        "https://eviltrout.com/some-path",
        skip_cache: true
      )

      expect(onebox).to be_present
      expect(onebox[:url]).to eq("https://eviltrout.com/some-path")
      expect(onebox[:title]).to eq(nil)
    end

    it "will lookup whitelisted domains" do
      SiteSetting.inline_onebox_domains_whitelist = "eviltrout.com"
      RetrieveTitle.stubs(:crawl).returns("Evil Trout's Blog")

      onebox = InlineOneboxer.lookup(
        "https://eviltrout.com/some-path",
        skip_cache: true
      )
      expect(onebox).to be_present
      expect(onebox[:url]).to eq("https://eviltrout.com/some-path")
      expect(onebox[:title]).to eq("Evil Trout's Blog")
    end

  end

end

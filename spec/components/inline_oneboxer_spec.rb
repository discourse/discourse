require 'rails_helper'
require_dependency 'inline_oneboxer'

describe InlineOneboxer do

  before do
    InlineOneboxer.clear_cache!
  end

  it "should return nothing with empty input" do
    expect(InlineOneboxer.new([]).process).to be_blank
  end

  it "can onebox a topic" do
    topic = Fabricate(:topic)
    results = InlineOneboxer.new([topic.url]).process
    expect(results).to be_present
    expect(results[0][:url]).to eq(topic.url)
    expect(results[0][:title]).to eq(topic.title)
  end

  it "doesn't onebox private messages" do
    topic = Fabricate(:private_message_topic)
    results = InlineOneboxer.new([topic.url]).process
    expect(results).to be_blank
  end

  context "caching" do
    it "puts an entry in the cache" do
      topic = Fabricate(:topic)
      expect(InlineOneboxer.cache_lookup(topic.url)).to be_blank

      result = InlineOneboxer.lookup(topic.url)
      expect(result).to be_present

      cached = InlineOneboxer.cache_lookup(topic.url)
      expect(cached).to be_present
      expect(cached[:url]).to eq(topic.url)
      expect(cached[:title]).to eq(topic.title)
    end
  end

  context ".lookup" do
    it "can lookup one link at a time" do
      topic = Fabricate(:topic)
      onebox = InlineOneboxer.lookup(topic.url)
      expect(onebox).to be_present
      expect(onebox[:url]).to eq(topic.url)
      expect(onebox[:title]).to eq(topic.title)
    end
  end

end


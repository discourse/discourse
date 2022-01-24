# frozen_string_literal: true

require 'rails_helper'

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
    fab!(:topic) { Fabricate(:topic) }

    before do
      InlineOneboxer.invalidate(topic.url)
    end

    it "puts an entry in the cache" do
      SiteSetting.enable_inline_onebox_on_all_domains = true
      url = "https://example.com/random-url"
      stub_request(:get, url).to_return(status: 200, body: "<html><head><title>a blog</title></head></html>")

      InlineOneboxer.invalidate(url)
      expect(InlineOneboxer.cache_lookup(url)).to be_blank

      result = InlineOneboxer.lookup(url)
      expect(result).to be_present

      cached = InlineOneboxer.cache_lookup(url)
      expect(cached[:url]).to eq(url)
      expect(cached[:title]).to eq('a blog')
    end

    it "puts an entry in the cache for failed onebox" do
      SiteSetting.enable_inline_onebox_on_all_domains = true
      url = "https://example.com/random-url"

      InlineOneboxer.invalidate(url)
      expect(InlineOneboxer.cache_lookup(url)).to be_blank

      result = InlineOneboxer.lookup(url)
      expect(result).to be_present

      cached = InlineOneboxer.cache_lookup(url)
      expect(cached[:url]).to eq(url)
      expect(cached[:title]).to be_nil
    end
  end

  context ".lookup" do
    let(:category) { Fabricate(:private_category, group: Group[:staff]) }
    let(:category2) { Fabricate(:private_category, group: Group[:staff]) }

    let(:admin) { Fabricate(:admin) }

    it "can lookup private topics if in same category" do
      topic = Fabricate(:topic, category: category)
      topic1 = Fabricate(:topic, category: category)
      topic2 = Fabricate(:topic, category: category2)

      # Link to `topic` from new topic (same category)
      onebox = InlineOneboxer.lookup(topic.url, user_id: admin.id, category_id: category.id, skip_cache: true)
      expect(onebox).to be_present
      expect(onebox[:url]).to eq(topic.url)
      expect(onebox[:title]).to eq(topic.title)

      # Link to `topic` from `topic`
      onebox = InlineOneboxer.lookup(topic.url, user_id: admin.id, category_id: topic.category_id, topic_id: topic.id, skip_cache: true)
      expect(onebox).to be_present
      expect(onebox[:url]).to eq(topic.url)
      expect(onebox[:title]).to eq(topic.title)

      # Link to `topic` from `topic1` (same category)
      onebox = InlineOneboxer.lookup(topic.url, user_id: admin.id, category_id: topic1.category_id, topic_id: topic1.id, skip_cache: true)
      expect(onebox).to be_present
      expect(onebox[:url]).to eq(topic.url)
      expect(onebox[:title]).to eq(topic.title)

      # Link to `topic` from `topic2` (different category)
      onebox = InlineOneboxer.lookup(topic.url, user_id: admin.id, category_id: topic2.category_id, topic_id: topic2.id, skip_cache: true)
      expect(onebox).to be_blank
    end

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

    it "will append the post number post author's username to the title" do
      topic = Fabricate(:topic, title: "Inline oneboxer")
      Fabricate(:post, topic: topic) # OP
      Fabricate(:post, topic: topic)
      lookup = -> (number) do
        InlineOneboxer.lookup(
          "#{topic.url}/#{number}",
          skip_cache: true
        )[:title]
      end
      posts = topic.reload.posts.order("post_number ASC")

      expect(lookup.call(0)).to eq("Inline oneboxer")
      expect(lookup.call(1)).to eq("Inline oneboxer")
      expect(lookup.call(2)).to eq("Inline oneboxer - #2 by #{posts[1].user.username}")

      Fabricate(:post, topic: topic, post_type: Post.types[:whisper])
      posts = topic.reload.posts.order("post_number ASC")
      # because the last post in the topic is a whisper, the onebox title
      # will be the first regular post directly before our whisper
      expect(lookup.call(3)).to eq("Inline oneboxer - #2 by #{posts[1].user.username}")
      expect(lookup.call(99)).to eq("Inline oneboxer - #2 by #{posts[1].user.username}")

      Fabricate(:post, topic: topic)
      posts = topic.reload.posts.order("post_number ASC")
      # username not appended to whisper posts
      expect(lookup.call(3)).to eq("Inline oneboxer - #3")
      expect(lookup.call(4)).to eq("Inline oneboxer - #4 by #{posts[3].user.username}")
      expect(lookup.call(99)).to eq("Inline oneboxer - #4 by #{posts[3].user.username}")
    end

    it "will not crawl domains that aren't allowlisted" do
      SiteSetting.enable_inline_onebox_on_all_domains = false
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

    it "will lookup allowlisted domains" do
      SiteSetting.allowed_inline_onebox_domains = "eviltrout.com"
      RetrieveTitle.stubs(:crawl).returns("Evil Trout's Blog")

      onebox = InlineOneboxer.lookup(
        "https://eviltrout.com/some-path",
        skip_cache: true
      )
      expect(onebox).to be_present
      expect(onebox[:url]).to eq("https://eviltrout.com/some-path")
      expect(onebox[:title]).to eq("Evil Trout's Blog")
    end

    describe "lookups for blocked domains in the hostname" do
      shared_examples "blocks the domain" do |setting, domain_to_test|
        it "does not retrieve title" do
          SiteSetting.blocked_onebox_domains = setting

          onebox = InlineOneboxer.lookup(domain_to_test, skip_cache: true)

          expect(onebox).to be_blank
        end
      end

      shared_examples "does not fulfil blocked domain" do |setting, domain_to_test|
        it "retrieves title" do
          SiteSetting.blocked_onebox_domains = setting

          onebox = InlineOneboxer.lookup(domain_to_test, skip_cache: true)

          expect(onebox).to be_present
        end
      end

      include_examples "blocks the domain", "api.cat.org|kitten.cloud", "https://api.cat.org"
      include_examples "blocks the domain", "api.cat.org|kitten.cloud", "http://kitten.cloud"

      include_examples "blocks the domain", "kitten.cloud", "http://cat.kitten.cloud"

      include_examples "blocks the domain", "api.cat.org", "https://api.cat.org/subdirectory/moar"
      include_examples "blocks the domain", "kitten.cloud", "https://cat.kitten.cloud/subd"

      include_examples "does not fulfil blocked domain", "kitten.cloud", "https://cat.2kitten.cloud"
      include_examples "does not fulfil blocked domain", "kitten.cloud", "https://cat.kitten.cloud9"
      include_examples "does not fulfil blocked domain", "api.cat.org", "https://api-cat.org"
    end
  end
end

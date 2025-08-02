# frozen_string_literal: true

RSpec.describe InlineOneboxer do
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

  describe "caching" do
    url = "https://example.com/good-url"

    before do
      SiteSetting.enable_inline_onebox_on_all_domains = true
      stub_request(:get, url).to_return(
        status: 200,
        body: "<html><head><title>a blog</title></head></html>",
      )

      InlineOneboxer.invalidate(url)
    end

    it "puts an entry in the cache" do
      expect(InlineOneboxer.cache_lookup(url)).to be_blank

      result = InlineOneboxer.lookup(url)
      expect(result[:title]).to be_present

      cached = InlineOneboxer.cache_lookup(url)
      expect(cached[:url]).to eq(url)
      expect(cached[:title]).to eq("a blog")
    end

    it "separates cache by default_locale" do
      expect(InlineOneboxer.cache_lookup(url)).to be_blank

      result = InlineOneboxer.lookup(url)
      expect(result[:title]).to be_present

      cached = InlineOneboxer.cache_lookup(url)
      expect(cached[:title]).to eq("a blog")

      SiteSetting.default_locale = "fr"

      expect(InlineOneboxer.cache_lookup(url)).to be_blank
    end

    it "separates cache by onebox_locale, when set" do
      expect(InlineOneboxer.cache_lookup(url)).to be_blank

      result = InlineOneboxer.lookup(url)
      expect(result[:title]).to be_present

      cached = InlineOneboxer.cache_lookup(url)
      expect(cached[:title]).to eq("a blog")

      SiteSetting.onebox_locale = "fr"

      expect(InlineOneboxer.cache_lookup(url)).to be_blank
    end
  end

  describe ".lookup" do
    let(:category) { Fabricate(:private_category, group: Group[:staff]) }
    let(:category2) { Fabricate(:private_category, group: Group[:staff]) }

    let(:admin) { Fabricate(:admin) }

    it "can lookup private topics if in same category" do
      topic = Fabricate(:topic, category: category)
      topic1 = Fabricate(:topic, category: category)
      topic2 = Fabricate(:topic, category: category2)

      # Link to `topic` from new topic (same category)
      onebox =
        InlineOneboxer.lookup(
          topic.url,
          user_id: admin.id,
          category_id: category.id,
          skip_cache: true,
        )
      expect(onebox).to be_present
      expect(onebox[:url]).to eq(topic.url)
      expect(onebox[:title]).to eq(topic.title)

      # Link to `topic` from `topic`
      onebox =
        InlineOneboxer.lookup(
          topic.url,
          user_id: admin.id,
          category_id: topic.category_id,
          topic_id: topic.id,
          skip_cache: true,
        )
      expect(onebox).to be_present
      expect(onebox[:url]).to eq(topic.url)
      expect(onebox[:title]).to eq(topic.title)

      # Link to `topic` from `topic1` (same category)
      onebox =
        InlineOneboxer.lookup(
          topic.url,
          user_id: admin.id,
          category_id: topic1.category_id,
          topic_id: topic1.id,
          skip_cache: true,
        )
      expect(onebox).to be_present
      expect(onebox[:url]).to eq(topic.url)
      expect(onebox[:title]).to eq(topic.title)

      # Link to `topic` from `topic2` (different category)
      onebox =
        InlineOneboxer.lookup(
          topic.url,
          user_id: admin.id,
          category_id: topic2.category_id,
          topic_id: topic2.id,
          skip_cache: true,
        )
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
      lookup = ->(number) do
        InlineOneboxer.lookup("#{topic.url}/#{number}", skip_cache: true)[:title]
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

      stub_request(:get, "https://eviltrout.com/some-path").to_return(
        status: 200,
        body: "<html><head><title>a blog</title></head></html>",
      )

      onebox = InlineOneboxer.lookup("https://eviltrout.com/some-path", skip_cache: true)

      expect(onebox).to be_present
      expect(onebox[:url]).to eq("https://eviltrout.com/some-path")
      expect(onebox[:title]).to eq("a blog")
    end

    it "will not return a onebox if it does not meet minimal length" do
      SiteSetting.enable_inline_onebox_on_all_domains = true

      stub_request(:get, "https://eviltrout.com/some-path").to_return(
        status: 200,
        body: "<html><head><title>a</title></head></html>",
      )

      onebox = InlineOneboxer.lookup("https://eviltrout.com/some-path", skip_cache: true)

      expect(onebox).to be_present
      expect(onebox[:url]).to eq("https://eviltrout.com/some-path")
      expect(onebox[:title]).to eq(nil)
    end

    it "will lookup allowlisted domains" do
      SiteSetting.allowed_inline_onebox_domains = "eviltrout.com"
      RetrieveTitle.stubs(:crawl).returns("Evil Trout's Blog")

      onebox = InlineOneboxer.lookup("https://eviltrout.com/some-path", skip_cache: true)
      expect(onebox).to be_present
      expect(onebox[:url]).to eq("https://eviltrout.com/some-path")
      expect(onebox[:title]).to eq("Evil Trout's Blog")
    end

    describe "lookups for blocked domains in the hostname" do
      shared_examples "blocks the domain" do |setting, domain_to_test|
        it "does not retrieve title" do
          stub_request(:get, domain_to_test).to_return(
            status: 200,
            body: "<html><head><title>hello world</title></head></html>",
          )
          SiteSetting.blocked_onebox_domains = setting

          onebox = InlineOneboxer.lookup(domain_to_test, skip_cache: true)

          expect(onebox).to be_blank
        end
      end

      shared_examples "does not fulfil blocked domain" do |setting, domain_to_test|
        it "retrieves title" do
          stub_request(:get, domain_to_test).to_return(
            status: 200,
            body: "<html><head><title>hello world</title></head></html>",
          )
          SiteSetting.blocked_onebox_domains = setting

          onebox = InlineOneboxer.lookup(domain_to_test, skip_cache: true)

          expect(onebox[:title]).to be_present
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

      it "doesn't retrieve title if a blocked domain is encountered anywhere in the redirect chain" do
        SiteSetting.blocked_onebox_domains = "redirect.com"
        stub_request(:get, "https://mainwebsite.com/blah").to_return(
          status: 301,
          body: "",
          headers: {
            "location" => "https://redirect.com/blah",
          },
        )
        stub_request(:get, "https://redirect.com/blah").to_return(
          status: 301,
          body: "",
          headers: {
            "location" => "https://finalwebsite.com/blah",
          },
        )
        stub_request(:get, "https://finalwebsite.com/blah").to_return(
          status: 200,
          body: "<html><head><title>hello world</title></head></html>",
        )
        onebox = InlineOneboxer.lookup("https://mainwebsite.com/blah", skip_cache: true)

        expect(onebox[:title]).to be_blank
      end

      it "doesn't retrieve title if the Discourse-No-Onebox header == 1" do
        stub_request(:get, "https://mainwebsite.com/blah").to_return(
          status: 200,
          body: "<html><head><title>hello world</title></head></html>",
          headers: {
            "Discourse-No-Onebox" => "1",
          },
        )
        onebox = InlineOneboxer.lookup("https://mainwebsite.com/blah", skip_cache: true)
        expect(onebox[:title]).to be_blank

        stub_request(:get, "https://mainwebsite.com/blah/2").to_return(
          status: 301,
          body: "",
          headers: {
            "location" => "https://mainwebsite.com/blah/2/redirect",
          },
        )
        stub_request(:get, "https://mainwebsite.com/blah/2/redirect").to_return(
          status: 301,
          body: "",
          headers: {
            "Discourse-No-Onebox" => "1",
            "location" => "https://somethingdoesnotmatter.com",
          },
        )
        onebox = InlineOneboxer.lookup("https://mainwebsite.com/blah/2", skip_cache: true)
        expect(onebox[:title]).to be_blank
        onebox = InlineOneboxer.lookup("https://mainwebsite.com/blah/2/redirect", skip_cache: true)
        expect(onebox[:title]).to be_blank
      end
    end

    context "when block_onebox_on_redirect is enabled" do
      before { SiteSetting.block_onebox_on_redirect = true }

      after { FinalDestination.clear_https_cache!("redirects.com") }

      it "doesn't onebox if the URL redirects" do
        stub_request(:get, "https://redirects.com/blah/gg").to_return(
          status: 301,
          body: "",
          headers: {
            "location" => "https://redirects.com/blah/gg/redirect",
          },
        )
        onebox = InlineOneboxer.lookup("https://redirects.com/blah/gg", skip_cache: true)
        expect(onebox[:title]).to be_blank
      end

      it "allows an initial http -> https redirect if the redirect URL is identical to the original" do
        stub_request(:get, "http://redirects.com/blah/gg").to_return(
          status: 301,
          body: "",
          headers: {
            "location" => "https://redirects.com/blah/gg",
          },
        )
        stub_request(:get, "https://redirects.com/blah/gg").to_return(
          status: 200,
          body: "<html><head><title>The Redirects Website</title></head></html>",
        )
        onebox = InlineOneboxer.lookup("http://redirects.com/blah/gg", skip_cache: true)
        expect(onebox[:title]).to eq("The Redirects Website")
      end

      it "doesn't allow an initial http -> https redirect if the redirect URL is different to the original" do
        stub_request(:get, "http://redirects.com/blah/gg").to_return(
          status: 301,
          body: "",
          headers: {
            "location" => "https://redirects.com/blah/gg/2",
          },
        )
        onebox = InlineOneboxer.lookup("http://redirects.com/blah/gg", skip_cache: true)
        expect(onebox[:title]).to be_blank
      end
    end

    it "censors external oneboxes" do
      Fabricate(:watched_word, action: WatchedWord.actions[:censor], word: "my")

      SiteSetting.enable_inline_onebox_on_all_domains = true

      stub_request(:get, "https://eviltrout.com/some-path").to_return(
        status: 200,
        body: "<html><head><title>welcome to my blog</title></head></html>",
      )

      onebox = InlineOneboxer.lookup("https://eviltrout.com/some-path", skip_cache: true)

      expect(onebox).to be_present
      expect(onebox[:url]).to eq("https://eviltrout.com/some-path")
      expect(onebox[:title]).to eq("welcome to ■■ blog")
    end

    it "does not try and censor external oneboxes returning a blank title" do
      Fabricate(:watched_word, action: WatchedWord.actions[:censor], word: "my")

      SiteSetting.enable_inline_onebox_on_all_domains = true

      stub_request(:get, "https://eviltrout.com/some-path").to_return(status: 404, body: "")

      onebox = InlineOneboxer.lookup("https://eviltrout.com/some-path", skip_cache: true)

      expect(onebox).to be_present
      expect(onebox[:url]).to eq("https://eviltrout.com/some-path")
      expect(onebox[:title]).to eq(nil)
    end
  end

  describe ".register_local_handler" do
    it "calls registered local handler" do
      InlineOneboxer.register_local_handler("wizard") do |url, route|
        { url: url, title: "Custom Onebox for Wizard" }
      end

      url = "#{Discourse.base_url}/wizard"
      results = InlineOneboxer.new([url], skip_cache: true).process
      expect(results).to be_present
      expect(results[0][:url]).to eq(url)
      expect(results[0][:title]).to eq("Custom Onebox for Wizard")
    end
  end
end

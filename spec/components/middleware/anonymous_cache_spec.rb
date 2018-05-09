require "rails_helper"
require_dependency "middleware/anonymous_cache"

describe Middleware::AnonymousCache::Helper do

  def env(opts = {})
    {
      "HTTP_HOST" => "http://test.com",
      "REQUEST_URI" => "/path?bla=1",
      "REQUEST_METHOD" => "GET",
      "rack.input" => ""
    }.merge(opts)
  end

  def new_helper(opts = {})
    Middleware::AnonymousCache::Helper.new(env(opts))
  end

  context "cachable?" do
    it "true by default" do
      expect(new_helper.cacheable?).to eq(true)
    end

    it "is false for non GET" do
      expect(new_helper("ANON_CACHE_DURATION" => 10, "REQUEST_METHOD" => "POST").cacheable?).to eq(false)
    end

    it "is false if it has an auth cookie" do
      expect(new_helper("HTTP_COOKIE" => "jack=1; _t=#{"1" * 32}; jill=2").cacheable?).to eq(false)
    end
  end

  context "per theme cache" do
    it "handles theme keys" do
      theme = Theme.create(name: "test", user_id: -1, user_selectable: true)

      with_bad_theme_key = new_helper("HTTP_COOKIE" => "theme_key=abc").cache_key
      with_no_theme_key = new_helper().cache_key

      expect(with_bad_theme_key).to eq(with_no_theme_key)

      with_good_theme_key = new_helper("HTTP_COOKIE" => "theme_key=#{theme.key}").cache_key

      expect(with_good_theme_key).not_to eq(with_no_theme_key)
    end
  end

  context "cached" do
    let!(:helper) do
      new_helper("ANON_CACHE_DURATION" => 10)
    end

    let!(:crawler) do
      new_helper("ANON_CACHE_DURATION" => 10, "HTTP_USER_AGENT" => "AdsBot-Google (+http://www.google.com/adsbot.html)")
    end

    after do
      helper.clear_cache
      crawler.clear_cache
    end

    it "handles brotli switching" do
      helper.cache([200, { "HELLO" => "WORLD" }, ["hello ", "my world"]])

      helper = new_helper("ANON_CACHE_DURATION" => 10)
      expect(helper.cached).to eq([200, { "X-Discourse-Cached" => "true", "HELLO" => "WORLD" }, ["hello my world"]])

      helper = new_helper("ANON_CACHE_DURATION" => 10, "HTTP_ACCEPT_ENCODING" => "gz, br")
      expect(helper.cached).to eq(nil)
    end

    it "returns cached data for cached requests" do
      helper.is_mobile = true
      expect(helper.cached).to eq(nil)
      helper.cache([200, { "HELLO" => "WORLD" }, ["hello ", "my world"]])

      helper = new_helper("ANON_CACHE_DURATION" => 10)
      helper.is_mobile = true
      expect(helper.cached).to eq([200, { "X-Discourse-Cached" => "true", "HELLO" => "WORLD" }, ["hello my world"]])

      expect(crawler.cached).to eq(nil)
      crawler.cache([200, { "HELLO" => "WORLD" }, ["hello ", "world"]])
      expect(crawler.cached).to eq([200, { "X-Discourse-Cached" => "true", "HELLO" => "WORLD" }, ["hello world"]])
    end
  end

end

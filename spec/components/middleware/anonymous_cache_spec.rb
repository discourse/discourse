require "spec_helper"
require_dependency "middleware/anonymous_cache"

describe Middleware::AnonymousCache::Helper do

  def new_helper(env={})
    Middleware::AnonymousCache::Helper.new({
      "HTTP_HOST" => "http://test.com",
      "REQUEST_URI" => "/path?bla=1",
      "REQUEST_METHOD" => "GET"
    }.merge(env))
  end

  context "cachable?" do
    it "true by default" do
      new_helper.cacheable?.should be_true
    end

    it "is false for non GET" do
      new_helper("ANON_CACHE_DURATION" => 10, "REQUEST_METHOD" => "POST").cacheable?.should be_false
    end

    it "is false if it has an auth cookie" do
      new_helper("HTTP_COOKIE" => "jack=1; _t=#{"1"*32}; jill=2").cacheable?.should be_false
    end
  end

  context "cached" do
    let!(:helper) do
      new_helper("ANON_CACHE_DURATION" => 10)
    end

    after do
      helper.clear_cache
    end

    it "returns cached data for cached requests" do
      helper.cached.should be_nil
      helper.cache([200, {"HELLO" => "WORLD"}, ["hello ", "world"]])
      helper.cached.should == [200, {"HELLO" => "WORLD"}, ["hello world"]]
    end
  end

end


# frozen_string_literal: true

require "rails_helper"

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

  it "includes ie in cache key" do
    helper = new_helper
    expect(helper.cache_key).to include("ie=false")

    helper = new_helper("HTTP_USER_AGENT" => "Mozilla/5.0 (Windows NT 6.3; Trident/7.0; rv:11.0) like Gecko")
    expect(helper.cache_key).to include("ie=true")
  end
end

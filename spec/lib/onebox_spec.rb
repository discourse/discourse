require "spec_helper"

describe Onebox do
  describe ".preview" do
    it "creates a cache that responds as expected" do
      url = "http://www.example.com"
      preview = Onebox.preview(url)
      cache = preview.cache
      expect(cache).to respond_to(:key?, :store, :fetch)
    end

    it "stores the value in cache if it doesn't exist" do
      url = "http://www.example.com"
      preview = Onebox.preview(url)
      cache = preview.cache
      expect(cache.key?(url)).to eq(true)
    end

    it "replaces the cache if the cache is expired" do
      url = "http://www.example.com"
      preview = Onebox.preview(url, cache: Moneta.new(:Memory, expires: 100000, serializer: :json))
      cache = preview.cache
      expect(cache.fetch(url)).to be(nil)
    end

  end
end

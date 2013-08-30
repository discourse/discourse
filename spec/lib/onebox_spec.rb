require "spec_helper"

describe Onebox do
  describe ".preview" do
    it "creates a cache that responds as expected" do
      url = "http://www.example.com"
      preview = Onebox.preview(url)
      cache = preview.cache
      expect(cache).to respond_to(:key?, :store, :fetch)
    end
  end
end

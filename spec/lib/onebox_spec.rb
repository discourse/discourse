require "spec_helper"

describe Onebox do
  describe ".preview" do
    it "should set the default cache as a hash" do
      url = "http://www.example.com"
      preview = Onebox.preview(url)
      cache = preview.cache
      expect(cache).to be_kind_of(Hash)
    end

  end
end

require "rails_helper"
require_dependency "category"

describe BasicCategorySerializer do

  let(:cdn) { "https://my.awesome.cdn" }
  let(:upload) { Fabricate(:upload) }
  let(:json) { BasicCategorySerializer.new(category, scope: Guardian.new, root: false).as_json }

  describe "logo_url" do

    let(:category) { Fabricate(:category, logo_url: upload.url) }

    it "uses absolute schemaless URL" do
      expect(json[:logo_url]).to eq("//test.localhost#{upload.url}")
    end

    it "uses CDN when available" do
      Discourse.stubs(:asset_host).returns(cdn)
      expect(json[:logo_url]).to eq("#{cdn}#{upload.url}")
    end

  end

  describe "background_url" do

    let(:category) { Fabricate(:category, background_url: upload.url) }

    it "uses absolute schemaless URL" do
      expect(json[:background_url]).to eq("//test.localhost#{upload.url}")
    end

    it "uses CDN when available" do
      Discourse.stubs(:asset_host).returns(cdn)
      expect(json[:background_url]).to eq("#{cdn}#{upload.url}")
    end

  end

end

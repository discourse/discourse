# frozen_string_literal: true

RSpec.describe Propshaft::Helper do
  describe "#compute_asset_path" do
    it "raises after exhausting retries in development" do
      Rails.env.stubs(:development?).returns(true)

      Rails.application.assets.load_path.expects(:clear_cache).times(3)

      helper_module = described_class
      helper = Class.new { include helper_module }.new
      missing_asset_path = "__nonexistent_propshaft_asset__.js"

      expect { helper.compute_asset_path(missing_asset_path) }.to raise_error(
        Propshaft::MissingAssetError,
        /#{missing_asset_path}/,
      )
    end
  end
end

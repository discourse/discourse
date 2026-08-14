# frozen_string_literal: true

RSpec.describe "assets:precompile" do
  describe "assets:precompile:asset_processor" do
    it "compiles the js processor" do
      FileUtils.rm_rf(File.dirname(AssetProcessor::BUNDLE.path))
      Rake::Task["assets:precompile:asset_processor"].actions.first.call

      expect(File.exist?(AssetProcessor::BUNDLE.path)).to eq(true)
    end
  end
end

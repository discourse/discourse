# frozen_string_literal: true

RSpec.describe "assets:precompile" do
  describe "assets:precompile:asset_processor" do
    it "compiles the js processor" do
      path = Rake::Task["assets:precompile:asset_processor"].actions.first.call

      expect(path).to end_with("tmp/asset-processor.js")
      expect(File.exist?(path)).to eq(true)
    end
  end
end

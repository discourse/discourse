# frozen_string_literal: true

RSpec.describe "assets:precompile" do
  describe "assets:precompile:asset_processor" do
    it "compiles the js processor" do
      FileUtils.rm_rf AssetProcessor::PROCESSOR_DIR
      Rake::Task["assets:precompile:asset_processor"].actions.first.call

      path = AssetProcessor.processor_file_path
      expect(File.exist?(path)).to eq(true)
    end
  end
end

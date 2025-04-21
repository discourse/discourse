# frozen_string_literal: true

RSpec.describe "assets:precompile" do
  describe "assets:precompile:theme_transpiler" do
    it "compiles the js processor" do
      path = Rake::Task["assets:precompile:theme_transpiler"].actions.first.call

      expect(path).to end_with("tmp/theme-transpiler.js")
      expect(File.exist?(path)).to eq(true)
    end
  end
end

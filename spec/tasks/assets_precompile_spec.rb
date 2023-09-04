# frozen_string_literal: true

RSpec.describe "assets:precompile" do
  before do
    Rake::Task.clear
    Discourse::Application.load_tasks
  end

  describe "assets:precompile:js_processor" do
    it "compiles the js processor" do
      out = capture_stdout { Rake::Task["assets:precompile:js_processor"].invoke }

      expect(out).to match(%r{Compiled js-processor: tmp/js-processor})
      path = out.match(/: (.+)/)[1]
      expect(File.exist?(path)).to eq(true)
    end
  end
end

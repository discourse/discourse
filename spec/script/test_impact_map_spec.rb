# frozen_string_literal: true

require "tmpdir"

require_relative "../../script/test_impact/map"

RSpec.describe TestImpact::Map do
  # app/models/thing.rb: methods at 5-7 (`double`) and 9-11 (`unused`), a
  # class-level block at line 3, a constant at line 2.
  def build_map(dir)
    path = File.join(dir, "recording-0-1.jsonl.gz")
    Zlib::GzipWriter.open(path) do |gz|
      gz.puts({ spec: "spec/double_spec.rb", files: { "app/models/thing.rb" => [[5, 7]] } }.to_json)
      gz.puts({ spec: "spec/block_spec.rb", files: { "app/models/thing.rb" => [[3, 3]] } }.to_json)
      gz.puts({ methods: { "app/models/thing.rb" => [[5, 7], [9, 11]] } }.to_json)
    end
    described_class.build([path])
  end

  def select(diff)
    Dir.mktmpdir("test-impact") { |dir| build_map(dir).select(TestImpact::Diff.parse(diff)) }
  end

  def diff(path, hunk_header)
    <<~DIFF
      diff --git a/#{path} b/#{path}
      --- a/#{path}
      +++ b/#{path}
      #{hunk_header}
    DIFF
  end

  describe "#select" do
    it "selects the specs that ran the method a hunk touches" do
      selection = select(diff("app/models/thing.rb", "@@ -6 +6 @@"))

      expect(selection.specs).to eq(["spec/double_spec.rb"])
    end

    it "selects the specs that ran a class-level block a hunk touches" do
      selection = select(diff("app/models/thing.rb", "@@ -3 +3 @@"))

      expect(selection.specs).to eq(["spec/block_spec.rb"])
    end

    it "selects every spec that ran the file for a hunk in load-time code" do
      selection = select(diff("app/models/thing.rb", "@@ -2 +2 @@"))

      expect(selection.specs).to eq(%w[spec/block_spec.rb spec/double_spec.rb])
    end

    it "reports a changed method no spec ran as untested" do
      selection = select(diff("app/models/thing.rb", "@@ -10 +10 @@"))

      expect(selection).to have_attributes(specs: [], untested: ["app/models/thing.rb:10-10"])
    end

    it "selects a changed spec file and reports files outside the map" do
      selection = select(diff("spec/other_spec.rb", "@@ -1 +1 @@") + <<~DIFF)
        diff --git a/app/models/new.rb b/app/models/new.rb
        new file mode 100644
        --- /dev/null
        +++ b/app/models/new.rb
        @@ -0,0 +1 @@
      DIFF

      expect(selection).to have_attributes(
        specs: ["spec/other_spec.rb"],
        unmapped: ["app/models/new.rb"],
      )
    end

    it "selects every spec that ran a renamed file" do
      selection = select(<<~DIFF)
        diff --git a/app/models/thing.rb b/app/models/renamed.rb
        similarity index 100%
        rename from app/models/thing.rb
        rename to app/models/renamed.rb
      DIFF

      expect(selection.specs).to eq(%w[spec/block_spec.rb spec/double_spec.rb])
    end
  end
end

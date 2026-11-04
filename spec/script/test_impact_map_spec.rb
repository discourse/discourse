# frozen_string_literal: true

require "tmpdir"

require_relative "../../script/test_impact/map"

RSpec.describe TestImpact::Map do
  let(:site_settings) { <<~YAML }
    posting:
      max_post_length:
        client: true
        default: 32000
      min_post_length:
        default: 20
  YAML

  let(:server_locale) { <<~YAML }
    en:
      post:
        edit: "Edit"
        delete: "Delete"
      topic:
        title: "Title"
  YAML

  # app/models/thing.rb: methods at 5-7 (`double`) and 9-11 (`unused`), a
  # class-level block at line 3, a constant at line 2.
  def build_map(dir)
    path = File.join(dir, "recording-0-1.jsonl.gz")
    Zlib::GzipWriter.open(path) do |gz|
      gz.puts(
        {
          spec: "spec/double_spec.rb",
          seconds: 2.5,
          files: {
            "app/models/thing.rb" => [[5, 7]],
            "frontend/discourse/app/thing.js" => [[1, 20], [5, 8]],
          },
          settings: ["max_post_length"],
          keys: ["post"],
          locales: ["en"],
        }.to_json,
      )
      gz.puts(
        {
          spec: "spec/block_spec.rb",
          seconds: 1.5,
          files: {
            "app/models/thing.rb" => [[3, 3]],
            "frontend/discourse/app/thing.js" => [[1, 20], [10, 12]],
          },
          settings: ["min_post_length"],
          keys: %w[post.edit topic.title],
          locales: %w[en fr],
          reads: ["spec/fixtures/logo.png"],
        }.to_json,
      )
      gz.puts(
        {
          methods: {
            "app/models/thing.rb" => [[5, 7], [9, 11]],
            "frontend/discourse/app/thing.js" => [[1, 20], [5, 8], [10, 12]],
          },
        }.to_json,
      )
    end
    described_class.build([path])
  end

  def select(diff)
    sources = {
      "config/site_settings.yml" => site_settings,
      "config/locales/server.en.yml" => server_locale,
      "config/locales/server.fr.yml" => server_locale.sub("en:", "fr:"),
      "config/locales/server.de.yml" => server_locale.sub("en:", "de:"),
    }
    Dir.mktmpdir("test-impact") do |dir|
      build_map(dir).select(TestImpact::Diff.parse(diff), source: sources.method(:[]))
    end
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

    it "selects for a hunk spanning a method and code outside it the specs of both" do
      selection = select(diff("app/models/thing.rb", "@@ -2,5 +2,5 @@"))

      expect(selection.specs).to eq(%w[spec/block_spec.rb spec/double_spec.rb])
    end

    it "selects the specs that ran the innermost function a hunk falls in" do
      inner = select(diff("frontend/discourse/app/thing.js", "@@ -6 +6 @@"))
      outer = select(diff("frontend/discourse/app/thing.js", "@@ -15 +15 @@"))

      expect([inner.specs, outer.specs]).to eq(
        [["spec/double_spec.rb"], %w[spec/block_spec.rb spec/double_spec.rb]],
      )
    end

    it "selects the specs that read a changed setting" do
      selection = select(diff("config/site_settings.yml", "@@ -4 +4 @@"))

      expect(selection.specs).to eq(["spec/double_spec.rb"])
    end

    it "reports a change to a settings category, which names no setting" do
      selection = select(diff("config/site_settings.yml", "@@ -1 +1 @@"))

      expect(selection).to have_attributes(specs: [], unmapped: ["config/site_settings.yml"])
    end

    it "selects the specs that looked up a changed English key or a key above it" do
      selection = select(diff("config/locales/server.en.yml", "@@ -3 +3 @@"))

      expect(selection.specs).to eq(%w[spec/block_spec.rb spec/double_spec.rb])
    end

    it "selects only the specs that used another locale for a change to its file" do
      french = select(diff("config/locales/server.fr.yml", "@@ -3 +3 @@"))
      german = select(diff("config/locales/server.de.yml", "@@ -3 +3 @@"))

      expect([french.specs, german.specs]).to eq([["spec/block_spec.rb"], []])
    end

    it "selects the specs that read a changed data file" do
      selection = select(diff("spec/fixtures/logo.png", "@@ -1 +1 @@"))

      expect(selection.specs).to eq(["spec/block_spec.rb"])
    end

    it "selects nothing for QUnit tests and documentation no spec ran or read" do
      selection =
        select(
          diff("frontend/discourse/tests/unit/thing-test.js", "@@ -1 +1 @@") +
            diff("plugins/chat/test/javascripts/thing-test.js", "@@ -1 +1 @@") +
            diff("docs/guide.md", "@@ -1 +1 @@") +
            diff("frontend/discourse/app/new.js", "@@ -1 +1 @@"),
        )

      expect(selection).to have_attributes(specs: [], unmapped: ["frontend/discourse/app/new.js"])
    end
  end

  describe "#seconds" do
    it "sums the recorded run time of the given spec files" do
      Dir.mktmpdir("test-impact") do |dir|
        map = build_map(dir)

        expect([map.seconds(["spec/double_spec.rb"]), map.seconds]).to eq([2.5, 4.0])
      end
    end
  end
end

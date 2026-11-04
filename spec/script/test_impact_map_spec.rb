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
          spec: "spec/integrity_spec.rb",
          files: {
          },
          reads: %w[config/site_settings.yml Gemfile.lock],
        }.to_json,
      )
      gz.puts(
        {
          methods: {
            "app/models/thing.rb" => [[5, 7], [9, 11]],
            "frontend/discourse/app/thing.js" => [[1, 20], [5, 8], [10, 12]],
            "lib/plugin/setup.rb" => [[2, 4]],
          },
          boot: {
            "lib/plugin/setup.rb" => [[2, 4]],
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

    it "selects the specs that read a changed setting or read the settings file" do
      selection = select(diff("config/site_settings.yml", "@@ -4 +4 @@"))

      expect(selection.specs).to eq(%w[spec/double_spec.rb spec/integrity_spec.rb])
    end

    it "reports a change to a settings category, which names no setting" do
      selection = select(diff("config/site_settings.yml", "@@ -1 +1 @@"))

      expect(selection).to have_attributes(
        specs: ["spec/integrity_spec.rb"],
        unmapped: ["config/site_settings.yml"],
      )
    end

    it "reports a change to a method boot ran" do
      selection = select(diff("lib/plugin/setup.rb", "@@ -3 +3 @@"))

      expect(selection).to have_attributes(specs: [], unmapped: ["lib/plugin/setup.rb"])
    end

    it "reports a change to the dependencies even when a spec read the file" do
      selection =
        select(
          diff("Gemfile.lock", "@@ -3 +3 @@") + diff("plugins/chat/package.json", "@@ -1 +1 @@"),
        )

      expect(selection).to have_attributes(
        specs: [],
        unmapped: %w[Gemfile.lock plugins/chat/package.json],
      )
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

    it "selects a changed QUnit test file" do
      selection = select(diff("plugins/chat/test/javascripts/thing-test.gjs", "@@ -1 +1 @@"))

      expect(selection.specs).to eq(["plugins/chat/test/javascripts/thing-test.gjs"])
    end

    it "selects nothing for test support and documentation no spec ran or read" do
      selection =
        select(
          diff("frontend/discourse/tests/helpers/thing.js", "@@ -1 +1 @@") +
            diff("docs/guide.md", "@@ -1 +1 @@") +
            diff("frontend/discourse/type-tests/thing-test.ts", "@@ -1 +1 @@") +
            diff("frontend/discourse/app/new.js", "@@ -1 +1 @@"),
        )

      expect(selection).to have_attributes(specs: [], unmapped: ["frontend/discourse/app/new.js"])
    end

    it "selects nothing for deleting a file no spec loaded or read" do
      selection = select(<<~DIFF)
        diff --git a/frontend/discourse/app/unused.js b/frontend/discourse/app/unused.js
        deleted file mode 100644
        --- a/frontend/discourse/app/unused.js
        +++ /dev/null
        @@ -1,3 +0,0 @@
      DIFF

      expect(selection).to have_attributes(specs: [], unmapped: [])
    end

    it "selects every spec that ran a deleted file" do
      selection = select(<<~DIFF)
        diff --git a/app/models/thing.rb b/app/models/thing.rb
        deleted file mode 100644
        --- a/app/models/thing.rb
        +++ /dev/null
        @@ -1,11 +0,0 @@
      DIFF

      expect(selection.specs).to eq(%w[spec/block_spec.rb spec/double_spec.rb])
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

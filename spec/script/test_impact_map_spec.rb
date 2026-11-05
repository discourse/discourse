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

  let(:gemfile_lock) { <<~LOCK }
    GEM
      remote: https://rubygems.org/
      specs:
        crass (1.0.7)
        rack (3.0.0)
        rubocop (1.80.0)
        sanitize (7.0.0)
          crass (~> 1.0.2)
        oj (3.16.0)

    PLATFORMS
      ruby

    DEPENDENCIES
      sanitize

    RUBY VERSION
       ruby 4.0.0p0

    BUNDLED WITH
       2.7.0
  LOCK

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
          tables: ["posts"],
          gems: %w[crass sanitize],
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
          tables: %w[topics chat_messages],
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
          gems: {
            loaded: %w[crass oj rack sanitize],
            boot: ["rack"],
            native: ["oj"],
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
      "Gemfile.lock" => gemfile_lock,
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

    def new_file(path)
      <<~DIFF
        diff --git a/#{path} b/#{path}
        new file mode 100644
        --- /dev/null
        +++ b/#{path}
        @@ -0,0 +1 @@
      DIFF
    end

    it "selects a changed spec file and reports a new file as reached through what loads it" do
      selection = select(diff("spec/other_spec.rb", "@@ -1 +1 @@") + new_file("app/models/new.rb"))

      expect(selection).to have_attributes(
        specs: ["spec/other_spec.rb"],
        unmapped: [],
        untested: ["app/models/new.rb: new, selected through what loads it"],
      )
    end

    it "reports a new file loaded by convention as outside the map" do
      selection =
        select(
          new_file("config/initializers/100-new.rb") +
            new_file("plugins/chat/assets/javascripts/discourse/connectors/outlet/new.gjs") +
            new_file("frontend/discourse/app/instance-initializers/new.js"),
        )

      expect(selection.unmapped).to eq(
        %w[
          config/initializers/100-new.rb
          frontend/discourse/app/instance-initializers/new.js
          plugins/chat/assets/javascripts/discourse/connectors/outlet/new.gjs
        ],
      )
    end

    it "selects for a new file the specs that read the files beside it" do
      selection = select(new_file("spec/fixtures/banner.png"))

      expect(selection.specs).to eq(["spec/block_spec.rb"])
    end

    it "selects every spec that ran a file converted to TypeScript" do
      selection = select(<<~DIFF + new_file("frontend/discourse/app/thing.ts"))
        diff --git a/frontend/discourse/app/thing.js b/frontend/discourse/app/thing.js
        deleted file mode 100644
        --- a/frontend/discourse/app/thing.js
        +++ /dev/null
        @@ -1,20 +0,0 @@
      DIFF

      expect(selection).to have_attributes(
        specs: %w[spec/block_spec.rb spec/double_spec.rb],
        unmapped: [],
        untested: [],
      )
    end

    it "selects every spec that ran a renamed file the map knows by its new path" do
      selection = select(<<~DIFF)
        diff --git a/app/models/old_thing.rb b/app/models/thing.rb
        similarity index 80%
        rename from app/models/old_thing.rb
        rename to app/models/thing.rb
        --- a/app/models/old_thing.rb
        +++ b/app/models/thing.rb
        @@ -40 +40 @@
      DIFF

      expect(selection).to have_attributes(
        specs: %w[spec/block_spec.rb spec/double_spec.rb],
        unmapped: [],
      )
    end

    it "selects nothing for files the Tests workflow never runs" do
      selection =
        select(
          diff("migrations/lib/converter.rb", "@@ -1 +1 @@") +
            diff("script/bulk_import/base.rb", "@@ -1 +1 @@") + diff(".gitignore", "@@ -1 +1 @@") +
            diff("plugins/chat/.gitignore", "@@ -1 +1 @@") + diff("CODEOWNERS", "@@ -1 +1 @@") +
            diff(".rubocop.yml", "@@ -1 +1 @@"),
        )

      expect(selection).to have_attributes(specs: [], unmapped: [])
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
        specs: ["spec/integrity_spec.rb"],
        unmapped: %w[Gemfile.lock plugins/chat/package.json],
      )
    end

    it "selects for a gem update the specs that ran the gem, and the lockfile's readers" do
      # The dependency line under sanitize.
      selection = select(diff("Gemfile.lock", "@@ -8 +8 @@"))

      expect(selection).to have_attributes(
        specs: %w[spec/double_spec.rb spec/integrity_spec.rb],
        unmapped: [],
      )
    end

    it "selects only the lockfile's readers for a gem the suite never loaded" do
      selection = select(diff("Gemfile.lock", "@@ -6 +6 @@"))

      expect(selection).to have_attributes(specs: ["spec/integrity_spec.rb"], unmapped: [])
    end

    it "reports a gem that ran at boot or has a native extension, and other lockfile changes" do
      ["@@ -5 +5 @@", "@@ -9 +9 @@", "@@ -18 +18 @@", "@@ -21 +21 @@"].each do |hunk|
        expect(select(diff("Gemfile.lock", hunk)).unmapped).to eq(["Gemfile.lock"]), hunk
      end
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

    def new_migration(path, body)
      <<~DIFF + body.lines.map { |line| "+#{line}" }.join
        diff --git a/#{path} b/#{path}
        new file mode 100644
        --- /dev/null
        +++ b/#{path}
        @@ -0,0 +1,#{body.lines.size} @@
      DIFF
    end

    it "selects the specs that queried a table a migration changes" do
      selection = select(new_migration("db/migrate/20261104000000_add_thing.rb", <<~RUBY))
        class AddThing < ActiveRecord::Migration[8.0]
          def change
            add_column :posts, :thing, :integer
          end
        end
      RUBY

      expect(selection).to have_attributes(specs: ["spec/double_spec.rb"], unmapped: [])
    end

    it "selects the specs that queried a model's table a data migration changes" do
      selection =
        select(new_migration("plugins/chat/db/post_migrate/20261104000000_fix.rb", <<~RUBY))
        class Fix < ActiveRecord::Migration[8.0]
          def up
            Chat::Message.where(deleted_at: nil).update_all(thing: 1)
          end
        end
      RUBY

      expect(selection).to have_attributes(specs: ["spec/block_spec.rb"], unmapped: [])
    end

    it "reports a migration that names no table a spec queried" do
      selection = select(new_migration("db/migrate/20261104000000_create_widgets.rb", <<~RUBY))
        class CreateWidgets < ActiveRecord::Migration[8.0]
          def change
            create_table :widgets
          end
        end
      RUBY

      expect(selection).to have_attributes(
        specs: [],
        unmapped: ["db/migrate/20261104000000_create_widgets.rb"],
      )
    end

    it "selects nothing for the schema dump" do
      selection = select(diff("db/structure.sql", "@@ -10 +10 @@"))

      expect(selection).to have_attributes(specs: [], unmapped: [])
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

RSpec.describe TestImpact::Job do
  let(:specs) do
    %w[
      spec/models/post_spec.rb
      spec/system/composer_spec.rb
      plugins/chat/spec/models/chat_message_spec.rb
      plugins/chat/spec/system/drawer_spec.rb
      plugins/poll/spec/system/poll_spec.rb
      plugins/discourse-events/spec/system/event_spec.rb
      frontend/discourse/tests/unit/lib/thing-test.js
      plugins/poll/test/javascripts/poll-test.gjs
      themes/horizon/spec/system/horizon_spec.rb
      tmp/themes/discourse-tag-icons/spec/system/icons_spec.rb
      themes/horizon/test/acceptance/card-test.gjs
      spec/deleted_spec.rb
    ]
  end

  def run(name, specs: self.specs, unmapped: [], recorded: self.specs)
    selection = TestImpact::Map::Selection.new(specs:, unmapped:, untested: [])
    described_class.new(name).run(
      selection,
      recorded:,
      bundled: %w[chat poll],
      exists: ->(path) { path != "spec/deleted_spec.rb" },
    )
  end

  it "gives each job the selected files it runs" do
    lists = {
      "backend/core" => ["spec/models/post_spec.rb"],
      "backend/plugins" => ["plugins/chat/spec/models/chat_message_spec.rb"],
      "system/core" => ["spec/system/composer_spec.rb"],
      "system/chat" => ["plugins/chat/spec/system/drawer_spec.rb"],
      "system/core-plugins" => ["plugins/poll/spec/system/poll_spec.rb"],
      "system/official-plugins" => ["plugins/discourse-events/spec/system/event_spec.rb"],
      "frontend/core" => ["frontend/discourse/tests/unit/lib/thing-test.js"],
      "frontend/plugins" => ["plugins/poll/test/javascripts/poll-test.gjs"],
      "system/themes" => %w[
        themes/horizon/spec/system/horizon_spec.rb
        tmp/themes/discourse-tag-icons/spec/system/icons_spec.rb
      ],
      "frontend/themes" => ["themes/horizon/test/acceptance/card-test.gjs"],
    }

    lists.each do |name, files|
      expect(run(name)).to match(["list", a_string_including("of the job's files"), files]), name
    end
  end

  it "runs a job whole when the selection is incomplete, and nothing when it selects none" do
    expect(run("backend/core", unmapped: ["Gemfile"]).first).to eq("full")
    expect(run("backend/core", specs: ["spec/system/composer_spec.rb"]).first).to eq("none")
  end

  it "runs QUnit whole when the files are too many to filter by path" do
    tests =
      (1..200).map { |n| "frontend/discourse/tests/unit/lib/a-long-test-file-name-#{n}-test.js" }

    expect(run("frontend/core", specs: tests).first).to eq("full")
  end

  it "runs a job whole when the map records none of its tests" do
    recorded = specs - ["themes/horizon/test/acceptance/card-test.gjs"]

    expect(run("frontend/themes", recorded:)).to match(
      ["full", "the map records no tests for frontend/themes", []],
    )
  end
end

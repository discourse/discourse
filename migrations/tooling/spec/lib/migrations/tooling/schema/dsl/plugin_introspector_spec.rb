# frozen_string_literal: true

require "stringio"
require "pathname"

RSpec.describe Migrations::Tooling::Schema::DSL::PluginIntrospector do
  let(:plugins_path) { Dir.mktmpdir("plugins") }

  after { FileUtils.rm_rf(plugins_path) }

  def create_plugin(name, migrations: {})
    plugin_dir = File.join(plugins_path, name)
    migrate_dir = File.join(plugin_dir, "db", "migrate")
    FileUtils.mkdir_p(migrate_dir)

    migrations.each { |filename, content| File.write(File.join(migrate_dir, filename), content) }
  end

  describe "#initialize" do
    it "uses the given plugins path" do
      introspector = described_class.new(plugins_path: "/custom/plugins")

      expect(introspector.instance_variable_get(:@plugins_path)).to eq("/custom/plugins")
    end

    it "falls back to the Rails plugins directory when no path is given" do
      rails_root = double("rails_root")
      allow(rails_root).to receive(:join).with("plugins").and_return(Pathname.new("/app/plugins"))
      stub_const("Rails", double("Rails", root: rails_root))

      introspector = described_class.new

      expect(introspector.instance_variable_get(:@plugins_path)).to eq("/app/plugins")
    end
  end

  describe "#core_migration_paths" do
    it "points at the Rails core migrate and post_migrate directories" do
      stub_const("Rails", double("Rails", root: Pathname.new("/app")))

      paths = described_class.allocate.send(:core_migration_paths)

      expect(paths).to eq(["/app/db/migrate", "/app/db/post_migrate"])
    end
  end

  describe ".compute_checksums" do
    it "returns a checksum per plugin" do
      create_plugin("chat", migrations: { "001_create_chat.rb" => "class CreateChat; end" })
      create_plugin("polls", migrations: { "001_create_polls.rb" => "class CreatePolls; end" })

      checksums = described_class.compute_checksums(plugins_path)

      expect(checksums.keys).to contain_exactly("chat", "polls")
      expect(checksums["chat"]).to be_a(String)
      expect(checksums["polls"]).to be_a(String)
      expect(checksums["chat"]).not_to eq(checksums["polls"])
    end

    it "excludes plugins without migration directories" do
      create_plugin("chat", migrations: { "001_create_chat.rb" => "class CreateChat; end" })
      FileUtils.mkdir_p(File.join(plugins_path, "no_migrations"))

      checksums = described_class.compute_checksums(plugins_path)

      expect(checksums.keys).to contain_exactly("chat")
    end

    it "changes when file content changes" do
      create_plugin("chat", migrations: { "001_create_chat.rb" => "class CreateChat; end" })

      checksum_before = described_class.compute_checksums(plugins_path)["chat"]

      File.write(
        File.join(plugins_path, "chat", "db", "migrate", "001_create_chat.rb"),
        "class CreateChatV2; end",
      )

      checksum_after = described_class.compute_checksums(plugins_path)["chat"]

      expect(checksum_before).not_to eq(checksum_after)
    end

    it "changes when a new migration file is added" do
      create_plugin("chat", migrations: { "001_create_chat.rb" => "class CreateChat; end" })

      checksum_before = described_class.compute_checksums(plugins_path)["chat"]

      File.write(
        File.join(plugins_path, "chat", "db", "migrate", "002_add_column.rb"),
        "class AddColumn; end",
      )

      checksum_after = described_class.compute_checksums(plugins_path)["chat"]

      expect(checksum_before).not_to eq(checksum_after)
    end

    it "returns an empty hash when there are no plugins" do
      expect(described_class.compute_checksums(plugins_path)).to eq({})
    end

    it "ignores non-Ruby files in a migration directory" do
      create_plugin("chat", migrations: { "001_create_chat.rb" => "class CreateChat; end" })

      checksum_before = described_class.compute_checksums(plugins_path)["chat"]

      File.write(File.join(plugins_path, "chat", "db", "migrate", "README.md"), "not a migration")

      checksum_after = described_class.compute_checksums(plugins_path)["chat"]

      expect(checksum_after).to eq(checksum_before)
    end

    it "incorporates the file name into the checksum" do
      create_plugin("chat", migrations: { "001_create_chat.rb" => "class CreateChat; end" })

      checksum_before = described_class.compute_checksums(plugins_path)["chat"]

      File.rename(
        File.join(plugins_path, "chat", "db", "migrate", "001_create_chat.rb"),
        File.join(plugins_path, "chat", "db", "migrate", "002_create_chat.rb"),
      )

      checksum_after = described_class.compute_checksums(plugins_path)["chat"]

      expect(checksum_after).not_to eq(checksum_before)
    end

    it "checksums plugins with both db/migrate and db/post_migrate directories" do
      create_plugin("chat", migrations: { "001_create_chat.rb" => "class CreateChat; end" })
      post_migrate_dir = File.join(plugins_path, "chat", "db", "post_migrate")
      FileUtils.mkdir_p(post_migrate_dir)

      checksum_before = described_class.compute_checksums(plugins_path)["chat"]

      File.write(File.join(post_migrate_dir, "001_post.rb"), "class Post; end")

      checksum_after = described_class.compute_checksums(plugins_path)["chat"]

      expect(checksum_before).to be_a(String)
      expect(checksum_after).not_to eq(checksum_before)
    end
  end

  describe ".checksum_for_paths" do
    # The reference checksum is computed by hand so the assertions pin the exact
    # value rather than comparing two calls that a mutation could distort together.
    def reference_checksum(*relative_files)
      digests =
        relative_files.map do |rel|
          path = File.join(plugins_path, rel)
          "#{File.basename(path)}:#{Digest::MD5.file(path).hexdigest}"
        end
      Digest::MD5.hexdigest(digests.join("\n"))
    end

    it "checksums the sorted Ruby files found across the given directories" do
      create_plugin(
        "chat",
        migrations: {
          "002_b.rb" => "class B; end",
          "001_a.rb" => "class A; end",
        },
      )
      migrate_dir = File.join(plugins_path, "chat", "db", "migrate")

      checksum = described_class.send(:checksum_for_paths, [migrate_dir])

      expect(checksum).to eq(
        reference_checksum("chat/db/migrate/001_a.rb", "chat/db/migrate/002_b.rb"),
      )
    end

    it "deduplicates repeated paths so they do not affect the checksum" do
      create_plugin("chat", migrations: { "001_create_chat.rb" => "class CreateChat; end" })
      migrate_dir = File.join(plugins_path, "chat", "db", "migrate")

      duplicated = described_class.send(:checksum_for_paths, [migrate_dir, migrate_dir])

      expect(duplicated).to eq(reference_checksum("chat/db/migrate/001_create_chat.rb"))
    end

    it "returns 'empty' when none of the paths contain Ruby files" do
      empty_dir = File.join(plugins_path, "empty")
      FileUtils.mkdir_p(empty_dir)

      expect(described_class.send(:checksum_for_paths, [empty_dir])).to eq("empty")
    end

    it "keeps only paths that are directories" do
      create_plugin("chat", migrations: { "001_create_chat.rb" => "class CreateChat; end" })
      migrate_dir = File.join(plugins_path, "chat", "db", "migrate")
      regular_file = File.join(plugins_path, "not_a_dir.rb")
      File.write(regular_file, "class Stray; end")

      checksum = described_class.send(:checksum_for_paths, [migrate_dir, regular_file])

      expect(checksum).to eq(reference_checksum("chat/db/migrate/001_create_chat.rb"))
    end
  end

  describe ".discover_plugins" do
    it "maps each plugin to its existing migration directories, sorted" do
      create_plugin("chat", migrations: { "001_create_chat.rb" => "class CreateChat; end" })
      FileUtils.mkdir_p(File.join(plugins_path, "chat", "db", "post_migrate"))

      plugins = described_class.discover_plugins(plugins_path)

      expect(plugins.keys).to eq(["chat"])
      expect(plugins["chat"]).to eq(
        [
          File.join(plugins_path, "chat", "db", "migrate"),
          File.join(plugins_path, "chat", "db", "post_migrate"),
        ],
      )
    end

    it "orders plugins alphabetically" do
      create_plugin("zebra", migrations: { "001.rb" => "class Z; end" })
      create_plugin("apple", migrations: { "001.rb" => "class A; end" })

      expect(described_class.discover_plugins(plugins_path).keys).to eq(%w[apple zebra])
    end

    it "skips entries that are not directories without stopping the scan" do
      # The stray file sorts before the plugin, so a `break` instead of `next`
      # in the guard would drop the plugin that follows it.
      File.write(File.join(plugins_path, "0001_stray_file"), "not a plugin")
      create_plugin("chat", migrations: { "001_create_chat.rb" => "class CreateChat; end" })

      expect(described_class.discover_plugins(plugins_path).keys).to eq(["chat"])
    end

    it "excludes plugins without any migration directory" do
      create_plugin("chat", migrations: { "001_create_chat.rb" => "class CreateChat; end" })
      FileUtils.mkdir_p(File.join(plugins_path, "no_migrations"))

      expect(described_class.discover_plugins(plugins_path).keys).to eq(["chat"])
    end
  end

  describe "#diff_schema" do
    let(:introspector) { described_class.allocate }

    def diff(before, after)
      introspector.send(:diff_schema, before, after)
    end

    it "reports newly created tables, sorted" do
      before = { tables: Set["users"], columns: { "users" => Set["id"] } }
      after = {
        tables: Set["users", "posts", "chats"],
        columns: {
          "users" => Set["id"],
          "posts" => Set["id"],
          "chats" => Set["id"],
        },
      }

      expect(diff(before, after)).to eq("tables" => %w[chats posts], "columns" => {})
    end

    it "reports new columns added to existing tables, sorted" do
      before = { tables: Set["users"], columns: { "users" => Set["id"] } }
      after = { tables: Set["users"], columns: { "users" => Set["id", "name", "email"] } }

      expect(diff(before, after)).to eq("tables" => [], "columns" => { "users" => %w[email name] })
    end

    it "does not list columns of a table that is itself new" do
      before = { tables: Set["users"], columns: { "users" => Set["id"] } }
      after = {
        tables: Set["users", "posts"],
        columns: {
          "users" => Set["id"],
          "posts" => Set["id", "title"],
        },
      }

      expect(diff(before, after)).to eq("tables" => ["posts"], "columns" => {})
    end

    it "treats a table missing from the before snapshot as having no prior columns" do
      before = { tables: Set["users"], columns: { "users" => Set["id"] } }
      after = {
        tables: Set["users"],
        columns: {
          "users" => Set["id"],
          "audit_logs" => Set["id"],
        },
      }

      # audit_logs is not a new table here (not in after[:tables]), so its columns
      # are diffed against an empty set.
      expect(diff(before, after)).to eq(
        "tables" => [],
        "columns" => {
          "audit_logs" => ["id"],
        },
      )
    end

    it "keeps scanning for new columns after encountering a new table" do
      before = { tables: Set["users"], columns: { "users" => Set["id"] } }
      # The new table "posts" is iterated before the existing "users" table, so a
      # `break` in the new-table guard would miss the new column on "users".
      after = {
        tables: Set["users", "posts"],
        columns: {
          "posts" => Set["id"],
          "users" => Set["id", "name"],
        },
      }

      expect(diff(before, after)).to eq("tables" => ["posts"], "columns" => { "users" => ["name"] })
    end

    it "returns nil when nothing changed" do
      before = { tables: Set["users"], columns: { "users" => Set["id"] } }
      after = { tables: Set["users"], columns: { "users" => Set["id"] } }

      expect(diff(before, after)).to be_nil
    end

    it "omits tables with no added columns from the columns hash" do
      before = { tables: Set["users", "posts"], columns: { "users" => Set["id"], "posts" => Set["id"] } }
      after = {
        tables: Set["users", "posts"],
        columns: {
          "users" => Set["id", "name"],
          "posts" => Set["id"],
        },
      }

      expect(diff(before, after)).to eq("tables" => [], "columns" => { "users" => ["name"] })
    end
  end

  describe "#snapshot_schema" do
    it "captures tables and their column names as sets from the connection" do
      connection =
        double(
          "connection",
          tables: %w[users posts],
        )
      allow(connection).to receive(:columns).with("users").and_return(
        [double(name: "id"), double(name: "name")],
      )
      allow(connection).to receive(:columns).with("posts").and_return([double(name: "id")])

      base = Class.new { define_singleton_method(:connection) { } }
      allow(base).to receive(:connection).and_return(connection)
      stub_const("ActiveRecord::Base", base)

      snapshot = described_class.allocate.send(:snapshot_schema)

      expect(snapshot[:tables]).to eq(Set["users", "posts"])
      expect(snapshot[:columns]).to eq(
        "users" => Set["id", "name"],
        "posts" => Set["id"],
      )
    end
  end

  describe "#build_result" do
    let(:introspector) { described_class.allocate }

    it "assembles the manifest with sorted failed plugins" do
      result =
        introspector.send(
          :build_result,
          { "chat" => { "tables" => ["chat_messages"] } },
          { "chat" => "abc123" },
          %w[zebra alpha],
        )

      expect(result).to eq(
        "plugins" => { "chat" => { "tables" => ["chat_messages"] } },
        "plugin_checksums" => { "chat" => "abc123" },
        "failed_plugins" => %w[alpha zebra],
        "incomplete" => true,
      )
    end

    it "marks the result as complete when no plugin failed" do
      result = introspector.send(:build_result, {}, {}, [])

      expect(result["failed_plugins"]).to eq([])
      expect(result["incomplete"]).to be false
    end
  end

  describe "#introspect_plugin" do
    it "returns the schema diff between before and after snapshots on success" do
      introspector = described_class.allocate
      stderr = StringIO.new
      snapshot_before = { tables: Set["users"], columns: { "users" => Set["id"] } }
      snapshot_after = { tables: Set["users"], columns: { "users" => Set["id"] } }

      allow(introspector).to receive(:snapshot_schema).and_return(snapshot_before, snapshot_after)
      allow(introspector).to receive(:run_plugin_migrations)
      allow(introspector).to receive(:diff_schema).with(
        snapshot_before,
        snapshot_after,
      ).and_return({ "tables" => ["chats"], "columns" => {} })

      result, failed = introspector.send(:introspect_plugin, "chat", ["paths"], stderr)

      expect(result).to eq("tables" => ["chats"], "columns" => {})
      expect(failed).to be false
      expect(introspector).to have_received(:run_plugin_migrations).with(["paths"])
    end

    it "drops partial schema data when a plugin migration fails" do
      introspector = described_class.allocate
      stderr = StringIO.new

      allow(introspector).to receive(:snapshot_schema).and_return({ tables: Set[], columns: {} })
      allow(introspector).to receive(:run_plugin_migrations).and_raise(StandardError, "boom")
      allow(introspector).to receive(:diff_schema)

      result, failed = introspector.send(:introspect_plugin, "chat", ["unused"], stderr)

      expect(result).to be_nil
      expect(failed).to be true
      expect(introspector).not_to have_received(:diff_schema)
      expect(stderr.string).to include("Warning: 'chat' migration error: boom")
    end
  end

  describe "#introspect_plugins" do
    it "introspects plugins in alphabetical order regardless of input order" do
      introspector = described_class.allocate
      stderr = StringIO.new
      plugins = { "zebra" => ["z.rb"], "apple" => ["a.rb"] }
      processed = []

      allow(introspector).to receive(:introspect_plugin) do |plugin_name, _paths, _stderr|
        processed << plugin_name
        [{ "tables" => [plugin_name], "columns" => {} }, false]
      end

      introspector.send(:introspect_plugins, plugins, stderr)

      expect(processed).to eq(%w[apple zebra])
    end

    it "omits succeeding plugins that introduced no schema changes" do
      introspector = described_class.allocate
      stderr = StringIO.new
      plugins = { "chat" => ["c.rb"], "polls" => ["p.rb"] }

      allow(introspector).to receive(:introspect_plugin).with("chat", ["c.rb"], stderr).and_return(
        [nil, false],
      )
      allow(introspector).to receive(:introspect_plugin).with("polls", ["p.rb"], stderr).and_return(
        [{ "tables" => ["polls"], "columns" => {} }, false],
      )

      plugin_data, failed_plugins = introspector.send(:introspect_plugins, plugins, stderr)

      expect(plugin_data).to eq("polls" => { "tables" => ["polls"], "columns" => {} })
      expect(failed_plugins).to eq([])
    end

    it "stops after the first failed plugin to avoid partial manifest data" do
      introspector = described_class.allocate
      stderr = StringIO.new
      plugins = {
        "alpha" => ["001_alpha.rb"],
        "broken" => ["001_broken.rb"],
        "omega" => ["001_omega.rb"],
      }

      allow(introspector).to receive(:introspect_plugin).with(
        "alpha",
        ["001_alpha.rb"],
        stderr,
      ).and_return([{ "tables" => ["alpha_table"], "columns" => {} }, false])
      allow(introspector).to receive(:introspect_plugin).with(
        "broken",
        ["001_broken.rb"],
        stderr,
      ).and_return([nil, true])

      plugin_data, failed_plugins = introspector.send(:introspect_plugins, plugins, stderr)

      expect(plugin_data).to eq("alpha" => { "tables" => ["alpha_table"], "columns" => {} })
      expect(failed_plugins).to eq(["broken"])
      expect(stderr.string).to include("stopping plugin introspection after 'broken' failed")
      expect(introspector).not_to have_received(:introspect_plugin).with(
        "omega",
        ["001_omega.rb"],
        stderr,
      )
    end
  end

  describe "#introspect" do
    it "runs migrations, discovers plugins and builds the result inside a temporary database" do
      introspector = described_class.allocate
      introspector.instance_variable_set(:@plugins_path, plugins_path)
      stderr = StringIO.new
      steps = []

      allow(introspector).to receive(:with_temporary_database) do |&block|
        steps << :with_temporary_database
        block.call(stderr)
      end
      allow(introspector).to receive(:run_core_migrations) { steps << :run_core_migrations }
      allow(introspector).to receive(:load_plugin_rake_tasks) { steps << :load_plugin_rake_tasks }
      allow(described_class).to receive(:discover_plugins).with(plugins_path).and_return(
        { "chat" => ["paths"] },
      )
      allow(introspector).to receive(:introspect_plugins).with(
        { "chat" => ["paths"] },
        stderr,
      ).and_return([{ "chat" => { "tables" => [] } }, []])
      allow(described_class).to receive(:compute_checksums).with(plugins_path).and_return(
        { "chat" => "abc" },
      )

      result = introspector.introspect

      expect(steps).to eq(%i[with_temporary_database run_core_migrations load_plugin_rake_tasks])
      expect(result).to eq(
        "plugins" => { "chat" => { "tables" => [] } },
        "plugin_checksums" => { "chat" => "abc" },
        "failed_plugins" => [],
        "incomplete" => false,
      )
    end
  end

  describe "#with_temporary_database" do
    it "starts a temporary database, yields with its connection, then restores and removes it" do
      introspector = described_class.allocate
      events = []

      original_config = { adapter: "postgresql", database: "original" }
      db_config = double("db_config", configuration_hash: original_config)
      base = Class.new
      base.define_singleton_method(:connection_db_config) { }
      base.define_singleton_method(:establish_connection) { |_| }
      allow(base).to receive(:connection_db_config).and_return(db_config)
      allow(base).to receive(:establish_connection) { |config| events << [:establish, config] }
      stub_const("ActiveRecord::Base", base)

      temp_db =
        double(
          "temp_db",
          connection_hash: { database: "temp" },
        )
      allow(temp_db).to receive(:start) { events << :start }
      allow(temp_db).to receive(:stop) { events << :stop }
      allow(temp_db).to receive(:remove) { events << :remove }
      allow(temp_db).to receive(:with_env) { |&block| block.call }
      temp_db_class = class_double("TemporaryDb").as_stubbed_const
      allow(temp_db_class).to receive(:new).and_return(temp_db)

      allow(introspector).to receive(:suppress_output) do |&block|
        block.call($stdout, $stderr)
      end

      yielded = nil
      introspector.send(:with_temporary_database) do |stderr|
        events << :yield
        yielded = stderr
      end

      expect(yielded).to be($stderr)
      expect(events).to eq(
        [
          :start,
          [:establish, { database: "temp" }],
          :yield,
          [:establish, original_config],
          :stop,
          :remove,
        ],
      )
    end

    it "restores the original connection and removes the database even when the block raises" do
      introspector = described_class.allocate
      events = []

      original_config = { database: "original" }
      db_config = double("db_config", configuration_hash: original_config)
      base = Class.new
      base.define_singleton_method(:connection_db_config) { }
      base.define_singleton_method(:establish_connection) { |_| }
      allow(base).to receive(:connection_db_config).and_return(db_config)
      allow(base).to receive(:establish_connection) { |config| events << [:establish, config] }
      stub_const("ActiveRecord::Base", base)

      temp_db = double("temp_db", connection_hash: { database: "temp" })
      allow(temp_db).to receive(:start)
      allow(temp_db).to receive(:stop) { events << :stop }
      allow(temp_db).to receive(:remove) { events << :remove }
      allow(temp_db).to receive(:with_env) { |&block| block.call }
      temp_db_class = class_double("TemporaryDb").as_stubbed_const
      allow(temp_db_class).to receive(:new).and_return(temp_db)

      allow(introspector).to receive(:suppress_output) { |&block| block.call($stdout, $stderr) }

      expect { introspector.send(:with_temporary_database) { raise "boom" } }.to raise_error("boom")

      expect(events).to include([:establish, original_config], :stop, :remove)
    end
  end

  describe "#suppress_output" do
    it "redirects stdout and stderr to StringIO inside the block and restores them after" do
      introspector = described_class.allocate
      original_stdout = $stdout
      original_stderr = $stderr
      captured = nil

      introspector.send(:suppress_output) do |old_stdout, old_stderr|
        captured = [old_stdout, old_stderr]
        expect($stdout).to be_a(StringIO)
        expect($stderr).to be_a(StringIO)
      end

      expect(captured).to eq([original_stdout, original_stderr])
      expect($stdout).to be(original_stdout)
      expect($stderr).to be(original_stderr)
    end

    it "restores the streams even when the block raises" do
      introspector = described_class.allocate
      original_stdout = $stdout
      original_stderr = $stderr

      expect {
        introspector.send(:suppress_output) { raise "boom" }
      }.to raise_error("boom")

      expect($stdout).to be(original_stdout)
      expect($stderr).to be(original_stderr)
    end
  end

  describe "#run_core_migrations" do
    it "migrates only the existing migration directories" do
      introspector = described_class.allocate
      existing = File.join(plugins_path, "db", "migrate")
      missing = File.join(plugins_path, "db", "post_migrate")
      FileUtils.mkdir_p(existing)
      allow(introspector).to receive(:core_migration_paths).and_return([existing, missing])

      context = double("migration_context", migrate: nil)
      migration_context_class = class_double("ActiveRecord::MigrationContext").as_stubbed_const
      allow(migration_context_class).to receive(:new).with([existing]).and_return(context)

      introspector.send(:run_core_migrations)

      expect(migration_context_class).to have_received(:new).with([existing])
      expect(context).to have_received(:migrate)
    end

    it "does not run a migration context when no directory exists" do
      introspector = described_class.allocate
      allow(introspector).to receive(:core_migration_paths).and_return(["/nope/migrate"])

      migration_context_class = class_double("ActiveRecord::MigrationContext").as_stubbed_const
      allow(migration_context_class).to receive(:new)

      introspector.send(:run_core_migrations)

      expect(migration_context_class).not_to have_received(:new)
    end
  end

  describe "#run_plugin_migrations" do
    it "migrates only the existing plugin migration directories" do
      introspector = described_class.allocate
      existing = File.join(plugins_path, "chat", "db", "migrate")
      FileUtils.mkdir_p(existing)

      context = double("migration_context", migrate: nil)
      migration_context_class = class_double("ActiveRecord::MigrationContext").as_stubbed_const
      allow(migration_context_class).to receive(:new).with([existing]).and_return(context)

      introspector.send(:run_plugin_migrations, [existing, "/nope"])

      expect(migration_context_class).to have_received(:new).with([existing])
      expect(context).to have_received(:migrate)
    end

    it "does nothing when none of the paths are directories" do
      introspector = described_class.allocate
      migration_context_class = class_double("ActiveRecord::MigrationContext").as_stubbed_const
      allow(migration_context_class).to receive(:new)

      introspector.send(:run_plugin_migrations, ["/nope"])

      expect(migration_context_class).not_to have_received(:new)
    end
  end

  describe "#load_plugin_rake_tasks" do
    it "defines the environment task and loads each plugin rake file" do
      introspector = described_class.allocate
      introspector.instance_variable_set(:@plugins_path, plugins_path)
      rake_file = File.join(plugins_path, "chat", "lib", "tasks", "chat.rake")
      FileUtils.mkdir_p(File.dirname(rake_file))
      File.write(rake_file, "")

      task_class = class_double("Rake::Task").as_stubbed_const
      allow(task_class).to receive(:task_defined?).with(:environment).and_return(false)
      allow(task_class).to receive(:define_task).with(:environment)
      allow(introspector).to receive(:load)

      introspector.send(:load_plugin_rake_tasks)

      expect(task_class).to have_received(:define_task).with(:environment)
      expect(introspector).to have_received(:load).with(rake_file)
    end

    it "does not redefine the environment task when it already exists" do
      introspector = described_class.allocate
      introspector.instance_variable_set(:@plugins_path, plugins_path)

      task_class = class_double("Rake::Task").as_stubbed_const
      allow(task_class).to receive(:task_defined?).with(:environment).and_return(true)
      allow(task_class).to receive(:define_task)
      allow(introspector).to receive(:load)

      introspector.send(:load_plugin_rake_tasks)

      expect(task_class).not_to have_received(:define_task)
    end
  end
end

# frozen_string_literal: true

require "stringio"

RSpec.describe Migrations::Database::Schema::DSL::PluginIntrospector do
  let(:plugins_path) { Dir.mktmpdir("plugins") }

  after { FileUtils.rm_rf(plugins_path) }

  def create_plugin(name, migrations: {})
    plugin_dir = File.join(plugins_path, name)
    migrate_dir = File.join(plugin_dir, "db", "migrate")
    FileUtils.mkdir_p(migrate_dir)

    migrations.each { |filename, content| File.write(File.join(migrate_dir, filename), content) }
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
  end

  describe "#introspect_plugin" do
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
end

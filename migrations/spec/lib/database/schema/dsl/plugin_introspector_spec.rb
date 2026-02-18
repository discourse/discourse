# frozen_string_literal: true

RSpec.describe Migrations::Database::Schema::DSL::PluginIntrospector do
  let(:plugins_path) { Dir.mktmpdir("plugins") }

  after { FileUtils.rm_rf(plugins_path) }

  def create_plugin(name, migrations: {})
    plugin_dir = File.join(plugins_path, name)
    migrate_dir = File.join(plugin_dir, "db", "migrate")
    FileUtils.mkdir_p(migrate_dir)

    migrations.each { |filename, content| File.write(File.join(migrate_dir, filename), content) }
  end

  describe "#discover_plugins" do
    it "finds plugins with migration directories" do
      create_plugin("chat", migrations: { "001_create_chat.rb" => "# migration" })
      create_plugin("polls", migrations: { "001_create_polls.rb" => "# migration" })

      introspector = described_class.new(plugins_path:)
      plugins = introspector.discover_plugins

      expect(plugins.keys).to contain_exactly("chat", "polls")
    end

    it "skips plugins without migration directories" do
      plugin_dir = File.join(plugins_path, "no_migrations")
      FileUtils.mkdir_p(plugin_dir)

      introspector = described_class.new(plugins_path:)
      plugins = introspector.discover_plugins

      expect(plugins).to be_empty
    end

    it "skips non-directory entries" do
      File.write(File.join(plugins_path, "not_a_plugin.txt"), "text")

      introspector = described_class.new(plugins_path:)
      plugins = introspector.discover_plugins

      expect(plugins).to be_empty
    end
  end

  describe "#compute_checksum_for_paths" do
    it "changes when file content changes" do
      create_plugin("chat", migrations: { "001_create_chat.rb" => "class CreateChat; end" })

      introspector = described_class.new(plugins_path:)
      paths = [File.join(plugins_path, "chat", "db", "migrate")]

      checksum_before = introspector.compute_checksum_for_paths(paths)

      File.write(
        File.join(plugins_path, "chat", "db", "migrate", "001_create_chat.rb"),
        "class CreateChatV2; end",
      )

      checksum_after = introspector.compute_checksum_for_paths(paths)

      expect(checksum_before).not_to eq(checksum_after)
    end

    it "changes when a new migration file is added" do
      create_plugin("chat", migrations: { "001_create_chat.rb" => "class CreateChat; end" })

      introspector = described_class.new(plugins_path:)
      paths = [File.join(plugins_path, "chat", "db", "migrate")]

      checksum_before = introspector.compute_checksum_for_paths(paths)

      File.write(
        File.join(plugins_path, "chat", "db", "migrate", "002_add_column.rb"),
        "class AddColumn; end",
      )

      checksum_after = introspector.compute_checksum_for_paths(paths)

      expect(checksum_before).not_to eq(checksum_after)
    end

    it "returns 'empty' when there are no migration files" do
      empty_dir = File.join(plugins_path, "empty")
      FileUtils.mkdir_p(empty_dir)

      introspector = described_class.new(plugins_path:)
      expect(introspector.compute_checksum_for_paths([])).to eq("empty")
      expect(introspector.compute_checksum_for_paths([empty_dir])).to eq("empty")
    end
  end

  describe "#compute_plugin_checksums" do
    it "returns a checksum per plugin" do
      create_plugin("chat", migrations: { "001_create_chat.rb" => "class CreateChat; end" })
      create_plugin("polls", migrations: { "001_create_polls.rb" => "class CreatePolls; end" })

      introspector = described_class.new(plugins_path:)
      checksums = introspector.compute_plugin_checksums

      expect(checksums.keys).to contain_exactly("chat", "polls")
      expect(checksums["chat"]).to be_a(String)
      expect(checksums["polls"]).to be_a(String)
      expect(checksums["chat"]).not_to eq(checksums["polls"])
    end
  end

  describe "#compute_all_checksums" do
    it "returns core and plugin checksums" do
      create_plugin("chat", migrations: { "001_create_chat.rb" => "class CreateChat; end" })

      introspector = described_class.new(plugins_path:)
      checksums = introspector.compute_all_checksums

      expect(checksums).to have_key("core")
      expect(checksums).to have_key("plugins")
      expect(checksums["plugins"]).to have_key("chat")
    end
  end
end

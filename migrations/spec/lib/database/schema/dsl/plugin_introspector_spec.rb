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
end

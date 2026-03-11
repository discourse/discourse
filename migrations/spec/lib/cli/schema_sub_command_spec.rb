# frozen_string_literal: true

require "thor"

RSpec.describe Migrations::CLI::SchemaSubCommand do
  let(:command) { described_class.new }

  describe "#ignore" do
    it "allows adding ignored tables without a reason" do
      Dir.mktmpdir do |tmpdir|
        ignored_path = File.join(tmpdir, "ignored.rb")
        File.write(ignored_path, "Migrations::Database::Schema.ignored do\nend\n")

        allow(Migrations::Database::Schema).to receive(:available_databases).and_return(
          %w[intermediate_db],
        )
        allow(Migrations::Database::Schema).to receive(:config_path).with(
          "intermediate_db",
        ).and_return(tmpdir)
        allow(command).to receive(:puts)
        allow(command).to receive(:options).and_return({ database: "intermediate_db" })

        command.ignore("users")

        content = File.read(ignored_path)
        expect(content).to include("table :users")
      end
    end
  end

  describe "#refresh_plugins" do
    it "reports incomplete manifest regeneration" do
      manifest = instance_double(Migrations::Database::Schema::DSL::PluginManifest)
      allow(manifest).to receive(:fresh?).and_return(false)
      allow(manifest).to receive(:regenerate!)
      allow(manifest).to receive(:incomplete?).and_return(true)
      allow(manifest).to receive(:failed_plugins).and_return(%w[chat])
      allow(manifest).to receive(:table_count).and_return(1)
      allow(manifest).to receive(:column_count).and_return(2)
      allow(manifest).to receive(:all_plugin_names).and_return(%w[chat])

      allow(command).to receive(:load_rails!)
      allow(command).to receive(:options).and_return({ database: "intermediate_db", force: false })
      allow(command).to receive(:puts)
      allow(Migrations::Database::Schema).to receive(:available_databases).and_return(
        %w[intermediate_db],
      )

      allow(Migrations::Database::Schema).to receive(:ensure_ready!).with(
        database: "intermediate_db",
        refresh_manifest: false,
      )
      allow(Migrations::Database::Schema).to receive(:plugin_manifest).and_return(manifest)

      command.refresh_plugins

      expect(command).to have_received(:puts).with(
        "Plugin manifest updated with warnings (failed plugins: chat)",
      )
    end
  end

  describe "#resolve" do
    it "fails fast when validation errors are present" do
      allow(command).to receive(:load_rails!)
      allow(command).to receive(:options).and_return({ database: "intermediate_db" })
      allow(command).to receive(:puts)
      allow(Migrations::Database::Schema).to receive(:available_databases).and_return(
        %w[intermediate_db],
      )
      allow(Migrations::Database::Schema).to receive(:validate).with(
        database: "intermediate_db",
      ).and_return(["bad config"])
      allow(Migrations::Database::Schema).to receive(:resolve)

      expect { command.resolve }.to raise_error(SystemExit)
      expect(Migrations::Database::Schema).not_to have_received(:resolve)
    end
  end

  describe "#validate" do
    it "treats resolved schema errors as validation failures" do
      allow(command).to receive(:load_rails!)
      allow(command).to receive(:options).and_return({ database: "intermediate_db" })
      allow(command).to receive(:puts)
      allow(Migrations::Database::Schema).to receive(:available_databases).and_return(
        %w[intermediate_db],
      )
      allow(Migrations::Database::Schema).to receive(:validate).with(
        database: "intermediate_db",
      ).and_return(["resolved schema problem"])

      expect { command.validate }.to raise_error(SystemExit)
    end
  end
end

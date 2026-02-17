# frozen_string_literal: true

require "thor"

RSpec.describe Migrations::CLI::SchemaSubCommand do
  let(:command) { described_class.new }

  describe "#ignore" do
    it "writes reason as a safe Ruby literal" do
      Dir.mktmpdir do |tmpdir|
        ignored_path = File.join(tmpdir, "ignored.rb")
        File.write(ignored_path, "Migrations::Database::Schema.ignored do\nend\n")

        allow(Migrations::Database::Schema).to receive(:config_path).with(
          "intermediate_db",
        ).and_return(tmpdir)
        allow(Migrations::Database::Schema).to receive(:available_databases).and_return(
          %w[intermediate_db],
        )
        allow(I18n).to receive(:t).and_call_original
        allow(I18n).to receive(:t).with("schema.ignore.success", table: "users").and_return("ok")
        allow(command).to receive(:puts)
        allow(command).to receive(:options).and_return(
          { reason: %q(#{1}\n"x"), database: "intermediate_db" },
        )

        command.ignore("users")

        content = File.read(ignored_path)
        expect(content).to include('table :users, "\#{1}')
        expect(content).to include("\\n\\\"x\\\"")
        expect(content).not_to include('table :users, "#{1}')
      end
    end

    it "raises when table name is invalid" do
      allow(Migrations::Database::Schema).to receive(:available_databases).and_return(
        %w[intermediate_db],
      )
      allow(command).to receive(:options).and_return(
        { reason: "not needed", database: "intermediate_db" },
      )

      expect { command.ignore("users;puts(1)") }.to raise_error(
        Migrations::Database::Schema::ConfigError,
        /Invalid table name/,
      )
    end

    it "raises when database option is unknown" do
      allow(command).to receive(:options).and_return({ reason: "not needed", database: "../tmp" })
      allow(Migrations::Database::Schema).to receive(:available_databases).and_return(
        %w[intermediate_db uploads_db],
      )

      expect { command.ignore("users") }.to raise_error(
        Migrations::Database::Schema::ConfigError,
        /Unknown database/,
      )
    end

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
        allow(I18n).to receive(:t).and_call_original
        allow(I18n).to receive(:t).with("schema.ignore.success", table: "users").and_return("ok")
        allow(command).to receive(:puts)
        allow(command).to receive(:options).and_return({ database: "intermediate_db" })

        command.ignore("users")

        content = File.read(ignored_path)
        expect(content).to include("table :users\n")
      end
    end
  end

  describe "#detect_plugins" do
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

      allow(Migrations::Database::Schema).to receive(:ensure_ready!).with(
        database: "intermediate_db",
      )
      allow(Migrations::Database::Schema).to receive(:plugin_manifest).with(
        database: "intermediate_db",
      ).and_return(manifest)

      allow(I18n).to receive(:t).with("schema.detect_plugins.detecting").and_return("detecting")
      allow(I18n).to receive(:t).with(
        "schema.detect_plugins.updated_incomplete",
        failed_plugins: "chat",
      ).and_return("updated_incomplete")
      allow(I18n).to receive(:t).with("schema.detect_plugins.tables", count: 1).and_return("tables")
      allow(I18n).to receive(:t).with("schema.detect_plugins.columns", count: 2).and_return(
        "columns",
      )
      allow(I18n).to receive(:t).with("schema.detect_plugins.plugins", names: "chat").and_return(
        "plugins",
      )

      command.detect_plugins

      expect(command).to have_received(:puts).with("updated_incomplete")
    end
  end
end

# frozen_string_literal: true

require "thor"

RSpec.describe Migrations::CLI::SchemaSubCommand do
  describe "#ignore" do
    let(:command) { described_class.new }

    it "writes reason as a safe Ruby literal" do
      Dir.mktmpdir do |tmpdir|
        ignored_path = File.join(tmpdir, "ignored.rb")
        File.write(ignored_path, "Migrations::Database::Schema.ignored do\nend\n")

        allow(Migrations::Database::Schema).to receive(:config_path).with(
          "intermediate_db",
        ).and_return(tmpdir)
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
      allow(command).to receive(:options).and_return(
        { reason: "not needed", database: "intermediate_db" },
      )

      expect { command.ignore("users;puts(1)") }.to raise_error(
        Migrations::Database::Schema::ConfigError,
        /Invalid table name/,
      )
    end
  end
end

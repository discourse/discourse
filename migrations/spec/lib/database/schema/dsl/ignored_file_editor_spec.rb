# frozen_string_literal: true

RSpec.describe Migrations::Database::Schema::DSL::IgnoredFileEditor do
  def with_ignored_file(content)
    Dir.mktmpdir do |tmpdir|
      ignored_path = File.join(tmpdir, "ignored.rb")
      File.write(ignored_path, content)
      yield tmpdir, ignored_path
    end
  end

  describe "#add_table" do
    it "preserves an existing tables-group reason when appending a table" do
      with_ignored_file(<<~RUBY) do |tmpdir, ignored_path|
          Migrations::Database::Schema.ignored do
            tables :a, :b, reason: "legacy"
          end
        RUBY
        allow(Migrations::Database::Schema::Helpers).to receive(:format_ruby_file)

        described_class.new(tmpdir).add_table(:c)

        content = File.read(ignored_path)
        expect(content).to include('tables :a, :b, :c, reason: "legacy"')
      end
    end

    it "inserts a standalone table entry when a reason is provided" do
      with_ignored_file(<<~RUBY) do |tmpdir, ignored_path|
            Migrations::Database::Schema.ignored do
              table :a
            end
          RUBY
        allow(Migrations::Database::Schema::Helpers).to receive(:format_ruby_file)

        described_class.new(tmpdir).add_table(:b, reason: "Legacy table")

        content = File.read(ignored_path)
        expect(content).to include('table :b, "Legacy table"')
      end
    end

    it "raises when the table is already ignored" do
      with_ignored_file(<<~RUBY) do |tmpdir, _ignored_path|
          Migrations::Database::Schema.ignored do
            tables :a, :b
          end
        RUBY
        expect { described_class.new(tmpdir).add_table(:a) }.to raise_error(
          Migrations::Database::Schema::ConfigError,
          /already ignored/,
        )
      end
    end

    it "raises when ignored.rb cannot be parsed" do
      with_ignored_file(
        "Migrations::Database::Schema.ignored do\n  tables :a,\n",
      ) do |tmpdir, _ignored_path|
        expect { described_class.new(tmpdir).add_table(:b) }.to raise_error(
          Migrations::Database::Schema::ConfigError,
          /Could not parse/,
        )
      end
    end

    it "raises when the ignored block is missing" do
      with_ignored_file(
        "Migrations::Database::Schema.table :users do\nend\n",
      ) do |tmpdir, _ignored_path|
        expect { described_class.new(tmpdir).add_table(:b) }.to raise_error(
          Migrations::Database::Schema::ConfigError,
          /Could not find `Migrations::Database::Schema.ignored do ... end`/,
        )
      end
    end
  end
end

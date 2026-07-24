# frozen_string_literal: true

RSpec.describe Migrations::Tooling::Schema::DSL::IgnoredFileEditor do
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
          Migrations::Tooling::Schema.ignored do
            tables :a, :b, reason: "legacy"
          end
        RUBY
        allow(Migrations::Tooling::Schema::Helpers).to receive(:format_ruby_file)

        described_class.new(tmpdir).add_table(:c)

        content = File.read(ignored_path)
        expect(content).to include('tables :a, :b, :c, reason: "legacy"')
      end
    end

    it "inserts a standalone table entry when a reason is provided" do
      with_ignored_file(<<~RUBY) do |tmpdir, ignored_path|
            Migrations::Tooling::Schema.ignored do
              table :a
            end
          RUBY
        allow(Migrations::Tooling::Schema::Helpers).to receive(:format_ruby_file)

        described_class.new(tmpdir).add_table(:b, reason: "Legacy table")

        content = File.read(ignored_path)
        expect(content).to include('table :b, "Legacy table"')
      end
    end

    it "raises when the table is already ignored" do
      with_ignored_file(<<~RUBY) do |tmpdir, _ignored_path|
          Migrations::Tooling::Schema.ignored do
            tables :a, :b
          end
        RUBY
        expect { described_class.new(tmpdir).add_table(:a) }.to raise_error(
          Migrations::Tooling::Schema::ConfigError,
          /already ignored/,
        )
      end
    end

    it "raises when ignored.rb cannot be parsed" do
      with_ignored_file(
        "Migrations::Tooling::Schema.ignored do\n  tables :a,\n",
      ) do |tmpdir, _ignored_path|
        expect { described_class.new(tmpdir).add_table(:b) }.to raise_error(
          Migrations::Tooling::Schema::ConfigError,
          /Could not parse/,
        )
      end
    end

    it "raises when the ignored block is missing" do
      with_ignored_file(
        "Migrations::Tooling::Schema.table :users do\nend\n",
      ) do |tmpdir, _ignored_path|
        expect { described_class.new(tmpdir).add_table(:b) }.to raise_error(
          Migrations::Tooling::Schema::ConfigError,
          /Could not find `Migrations::Tooling::Schema.ignored do ... end`/,
        )
      end
    end
  end

  describe "#remove_table" do
    it "removes a table from a tables group and preserves the reason" do
      with_ignored_file(<<~RUBY) do |tmpdir, ignored_path|
          Migrations::Tooling::Schema.ignored do
            tables :a, :b, :c, reason: "legacy"
          end
        RUBY
        allow(Migrations::Tooling::Schema::Helpers).to receive(:format_ruby_file)

        described_class.new(tmpdir).remove_table(:b)

        content = File.read(ignored_path)
        expect(content).to include('tables :a, :c, reason: "legacy"')
        expect(content).not_to include(":b")
      end
    end

    it "removes a standalone table entry entirely" do
      with_ignored_file(<<~RUBY) do |tmpdir, ignored_path|
          Migrations::Tooling::Schema.ignored do
            table :a, "Legacy table"
            tables :b, :c
          end
        RUBY
        allow(Migrations::Tooling::Schema::Helpers).to receive(:format_ruby_file)

        described_class.new(tmpdir).remove_table(:a)

        content = File.read(ignored_path)
        expect(content).not_to include(":a,")
        expect(content).not_to include("Legacy table")
        expect(content).to include("tables :b, :c")
      end
    end

    it "removes the whole group when the last table is removed" do
      with_ignored_file(<<~RUBY) do |tmpdir, ignored_path|
          Migrations::Tooling::Schema.ignored do
            tables :a
            tables :b, :c
          end
        RUBY
        allow(Migrations::Tooling::Schema::Helpers).to receive(:format_ruby_file)

        described_class.new(tmpdir).remove_table(:a)

        content = File.read(ignored_path)
        expect(content).not_to include("tables :a")
        expect(content).to include("tables :b, :c")
      end
    end

    it "removes a table from a multi-line tables group" do
      with_ignored_file(<<~RUBY) do |tmpdir, ignored_path|
          Migrations::Tooling::Schema.ignored do
            tables :aaa,
                   :bbb,
                   :ccc
          end
        RUBY
        allow(Migrations::Tooling::Schema::Helpers).to receive(:format_ruby_file)

        described_class.new(tmpdir).remove_table(:aaa)

        content = File.read(ignored_path)
        expect(content).to include("tables :bbb, :ccc")
        expect(content).not_to include(":aaa")
      end
    end

    it "raises when the table is not ignored" do
      with_ignored_file(<<~RUBY) do |tmpdir, _ignored_path|
          Migrations::Tooling::Schema.ignored do
            tables :a, :b
          end
        RUBY
        expect { described_class.new(tmpdir).remove_table(:c) }.to raise_error(
          Migrations::Tooling::Schema::ConfigError,
          /is not ignored/,
        )
      end
    end
  end
end

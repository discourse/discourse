# frozen_string_literal: true

RSpec.describe Migrations::Tooling::Schema::DSL::IgnoredFileEditor do
  def with_ignored_file(content)
    Dir.mktmpdir do |tmpdir|
      ignored_path = File.join(tmpdir, "ignored.rb")
      File.write(ignored_path, content)
      yield tmpdir, ignored_path
    end
  end

  # Runs a block with a ready editor whose formatter is stubbed out, so the
  # assertions see the exact bytes the editor writes (before any reformatting).
  def edit(content)
    with_ignored_file(content) do |tmpdir, ignored_path|
      allow(Migrations::Tooling::Schema::Helpers).to receive(:format_ruby_file)
      yield described_class.new(tmpdir), ignored_path
    end
  end

  describe "#add_table" do
    it "rejects a table name containing uppercase letters" do
      edit(<<~RUBY) do |editor, _ignored_path|
          Migrations::Tooling::Schema.ignored do
            tables :a
          end
        RUBY
        expect { editor.add_table("Bad-Name") }.to raise_error(
          Migrations::Tooling::Schema::ConfigError,
          "Invalid table name 'Bad-Name'. Use lowercase letters, numbers, and underscores.",
        )
      end
    end

    it "rejects a table name that starts valid but contains punctuation" do
      edit(<<~RUBY) do |editor, _ignored_path|
          Migrations::Tooling::Schema.ignored do
            tables :a
          end
        RUBY
        expect { editor.add_table("bad-name") }.to raise_error(
          Migrations::Tooling::Schema::ConfigError,
          /Invalid table name 'bad-name'/,
        )
      end
    end

    it "accepts a multi-character name with digits and underscores" do
      edit(<<~RUBY) do |editor, ignored_path|
          Migrations::Tooling::Schema.ignored do
            tables :a
          end
        RUBY
        editor.add_table(:user_role_2)

        expect(File.read(ignored_path)).to eq(<<~RUBY)
          Migrations::Tooling::Schema.ignored do
            tables :a, :user_role_2
          end
        RUBY
      end
    end

    it "raises when ignored.rb does not exist" do
      Dir.mktmpdir do |tmpdir|
        ignored_path = File.join(tmpdir, "ignored.rb")
        expect { described_class.new(tmpdir).add_table(:a) }.to raise_error(
          Migrations::Tooling::Schema::ConfigError,
          "ignored.rb not found at #{ignored_path}",
        )
      end
    end

    it "raises when the table is already ignored via a tables group" do
      edit(<<~RUBY) do |editor, _ignored_path|
          Migrations::Tooling::Schema.ignored do
            tables :a, :b
          end
        RUBY
        expect { editor.add_table(:a) }.to raise_error(
          Migrations::Tooling::Schema::ConfigError,
          "Table a is already ignored",
        )
      end
    end

    it "detects an already-ignored table listed after unrelated statements" do
      edit(<<~RUBY) do |editor, _ignored_path|
          Migrations::Tooling::Schema.ignored do
            x = 1
            other_call :z
            tables :a, :b
          end
        RUBY
        expect { editor.add_table(:a) }.to raise_error(
          Migrations::Tooling::Schema::ConfigError,
          /already ignored/,
        )
      end
    end

    it "does not treat a name from a non-table call as already ignored" do
      edit(<<~RUBY) do |editor, ignored_path|
          Migrations::Tooling::Schema.ignored do
            other_call :z
            tables :a, :b
          end
        RUBY
        editor.add_table(:z)

        expect(File.read(ignored_path)).to eq(<<~RUBY)
          Migrations::Tooling::Schema.ignored do
            other_call :z
            tables :a, :b, :z
          end
        RUBY
      end
    end

    it "raises when the table is already ignored via a standalone entry" do
      edit(<<~RUBY) do |editor, _ignored_path|
          Migrations::Tooling::Schema.ignored do
            table :a, "Legacy"
          end
        RUBY
        expect { editor.add_table(:a) }.to raise_error(
          Migrations::Tooling::Schema::ConfigError,
          /already ignored/,
        )
      end
    end

    it "appends to the last tables group, sorted, keeping the reason" do
      edit(<<~RUBY) do |editor, ignored_path|
          Migrations::Tooling::Schema.ignored do
            tables :a, :b
            tables :c, :e, reason: "legacy"
          end
        RUBY
        editor.add_table(:d)

        expect(File.read(ignored_path)).to eq(<<~RUBY)
          Migrations::Tooling::Schema.ignored do
            tables :a, :b
            tables :c, :d, :e, reason: "legacy"
          end
        RUBY
      end
    end

    it "handles appending to an empty tables group" do
      edit(<<~RUBY) do |editor, ignored_path|
          Migrations::Tooling::Schema.ignored do
            table :a
            tables
          end
        RUBY
        editor.add_table(:x)

        expect(File.read(ignored_path)).to eq(<<~RUBY)
          Migrations::Tooling::Schema.ignored do
            table :a
            tables :x
          end
        RUBY
      end
    end

    it "inserts a standalone entry with a reason before the closing end" do
      edit(<<~RUBY) do |editor, ignored_path|
          Migrations::Tooling::Schema.ignored do
            table :a
          end
        RUBY
        editor.add_table(:b, reason: "Legacy table")

        expect(File.read(ignored_path)).to eq(<<~RUBY)
          Migrations::Tooling::Schema.ignored do
            table :a

            table :b, "Legacy table"
          end
        RUBY
      end
    end

    it "inserts a standalone entry with a reason even when a tables group exists" do
      edit(<<~RUBY) do |editor, ignored_path|
          Migrations::Tooling::Schema.ignored do
            tables :a, :b
          end
        RUBY
        editor.add_table(:c, reason: "Legacy table")

        expect(File.read(ignored_path)).to eq(<<~RUBY)
          Migrations::Tooling::Schema.ignored do
            tables :a, :b

            table :c, "Legacy table"
          end
        RUBY
      end
    end

    it "inserts a standalone entry without a reason when there is no tables group" do
      edit(<<~RUBY) do |editor, ignored_path|
          Migrations::Tooling::Schema.ignored do
            table :a
          end
        RUBY
        editor.add_table(:b)

        expect(File.read(ignored_path)).to eq(<<~RUBY)
          Migrations::Tooling::Schema.ignored do
            table :a

            table :b
          end
        RUBY
      end
    end

    it "treats a blank reason as no reason" do
      edit(<<~RUBY) do |editor, ignored_path|
          Migrations::Tooling::Schema.ignored do
            tables :a
          end
        RUBY
        editor.add_table(:b, reason: "")

        expect(File.read(ignored_path)).to eq(<<~RUBY)
          Migrations::Tooling::Schema.ignored do
            tables :a

            table :b
          end
        RUBY
      end
    end

    it "reformats the file afterwards" do
      edit(<<~RUBY) do |editor, ignored_path|
          Migrations::Tooling::Schema.ignored do
            tables :a
          end
        RUBY
        expect(Migrations::Tooling::Schema::Helpers).to receive(:format_ruby_file).with(
          ignored_path,
        )

        editor.add_table(:b)
      end
    end

    it "raises with the joined parser details when ignored.rb cannot be parsed" do
      edit("Migrations::Tooling::Schema.ignored do\n  tables :a,\n") do |editor, _ignored_path|
        expect { editor.add_table(:b) }.to raise_error(
          Migrations::Tooling::Schema::ConfigError,
        ) do |error|
          expect(error.message).to match(/\ACould not parse .+ignored\.rb: /)
          # Every parser error is included, joined with ", ".
          expect(error.message).to include(
            "unexpected end-of-input; expected an argument, unexpected end-of-input",
          )
        end
      end
    end

    it "inserts a standalone entry into an empty ignored block" do
      edit(<<~RUBY) do |editor, ignored_path|
          Migrations::Tooling::Schema.ignored do
          end
        RUBY
        editor.add_table(:a)

        expect(File.read(ignored_path)).to eq(<<~RUBY)
          Migrations::Tooling::Schema.ignored do

            table :a
          end
        RUBY
      end
    end

    it "appends to the tables group while ignoring other statements" do
      edit(<<~RUBY) do |editor, ignored_path|
          Migrations::Tooling::Schema.ignored do
            x = 1
            tables :a, :b
            table :z, "note"
          end
        RUBY
        editor.add_table(:c)

        expect(File.read(ignored_path)).to eq(<<~RUBY)
          Migrations::Tooling::Schema.ignored do
            x = 1
            tables :a, :b, :c
            table :z, "note"
          end
        RUBY
      end
    end
  end

  describe "#remove_table" do
    it "raises when ignored.rb does not exist" do
      Dir.mktmpdir do |tmpdir|
        ignored_path = File.join(tmpdir, "ignored.rb")
        expect { described_class.new(tmpdir).remove_table(:a) }.to raise_error(
          Migrations::Tooling::Schema::ConfigError,
          "ignored.rb not found at #{ignored_path}",
        )
      end
    end

    it "removes a table from a tables group and keeps the reason" do
      edit(<<~RUBY) do |editor, ignored_path|
          Migrations::Tooling::Schema.ignored do
            tables :a, :b, :c, reason: "legacy"
          end
        RUBY
        editor.remove_table(:b)

        expect(File.read(ignored_path)).to eq(<<~RUBY)
          Migrations::Tooling::Schema.ignored do
            tables :a, :c, reason: "legacy"
          end
        RUBY
      end
    end

    it "removes a standalone table entry including its line" do
      edit(<<~RUBY) do |editor, ignored_path|
          Migrations::Tooling::Schema.ignored do
            table :a, "Legacy table"
            tables :b, :c
          end
        RUBY
        editor.remove_table(:a)

        expect(File.read(ignored_path)).to eq(<<~RUBY)
          Migrations::Tooling::Schema.ignored do
            tables :b, :c
          end
        RUBY
      end
    end

    it "removes the whole group when its last table is removed" do
      edit(<<~RUBY) do |editor, ignored_path|
          Migrations::Tooling::Schema.ignored do
            tables :a
            tables :b, :c
          end
        RUBY
        editor.remove_table(:a)

        expect(File.read(ignored_path)).to eq(<<~RUBY)
          Migrations::Tooling::Schema.ignored do
            tables :b, :c
          end
        RUBY
      end
    end

    it "removes a table from a multi-line tables group" do
      edit(<<~RUBY) do |editor, ignored_path|
          Migrations::Tooling::Schema.ignored do
            tables :aaa,
                   :bbb,
                   :ccc
          end
        RUBY
        editor.remove_table(:aaa)

        expect(File.read(ignored_path)).to eq(<<~RUBY)
          Migrations::Tooling::Schema.ignored do
            tables :bbb, :ccc
          end
        RUBY
      end
    end

    it "removes the matching entry when several entries exist" do
      edit(<<~RUBY) do |editor, ignored_path|
          Migrations::Tooling::Schema.ignored do
            table :a
            table :b
            tables :c, :d
          end
        RUBY
        editor.remove_table(:b)

        expect(File.read(ignored_path)).to eq(<<~RUBY)
          Migrations::Tooling::Schema.ignored do
            table :a
            tables :c, :d
          end
        RUBY
      end
    end

    it "handles multibyte content when deleting a line" do
      edit(<<~RUBY) do |editor, ignored_path|
          Migrations::Tooling::Schema.ignored do
            # café ☕ historique
            table :a
            tables :b, :c
          end
        RUBY
        editor.remove_table(:a)

        expect(File.read(ignored_path)).to eq(<<~RUBY)
          Migrations::Tooling::Schema.ignored do
            # café ☕ historique
            tables :b, :c
          end
        RUBY
      end
    end

    it "ignores non-table calls that mention the name" do
      edit(<<~RUBY) do |editor, _ignored_path|
          Migrations::Tooling::Schema.ignored do
            some_other_call :a
          end
        RUBY
        expect { editor.remove_table(:a) }.to raise_error(
          Migrations::Tooling::Schema::ConfigError,
          /is not ignored/,
        )
      end
    end

    it "skips non-call statements in the block" do
      edit(<<~RUBY) do |editor, ignored_path|
          Migrations::Tooling::Schema.ignored do
            x = 1
            tables :a, :b
          end
        RUBY
        editor.remove_table(:a)

        expect(File.read(ignored_path)).to eq(<<~RUBY)
          Migrations::Tooling::Schema.ignored do
            x = 1
            tables :b
          end
        RUBY
      end
    end

    it "raises when the table is not ignored" do
      edit(<<~RUBY) do |editor, _ignored_path|
          Migrations::Tooling::Schema.ignored do
            tables :a, :b
          end
        RUBY
        expect { editor.remove_table(:c) }.to raise_error(
          Migrations::Tooling::Schema::ConfigError,
          "Table 'c' is not ignored",
        )
      end
    end

    it "raises when the ignored block is empty" do
      edit(<<~RUBY) do |editor, _ignored_path|
          Migrations::Tooling::Schema.ignored do
          end
        RUBY
        expect { editor.remove_table(:a) }.to raise_error(
          Migrations::Tooling::Schema::ConfigError,
          /is not ignored/,
        )
      end
    end

    it "reformats the file afterwards" do
      edit(<<~RUBY) do |editor, ignored_path|
          Migrations::Tooling::Schema.ignored do
            tables :a, :b
          end
        RUBY
        expect(Migrations::Tooling::Schema::Helpers).to receive(:format_ruby_file).with(
          ignored_path,
        )

        editor.remove_table(:a)
      end
    end
  end

  describe "locating the ignored declaration" do
    it "finds a declaration nested inside another node" do
      edit(<<~RUBY) do |editor, ignored_path|
          module Foo
            Migrations::Tooling::Schema.ignored do
              tables :a
            end
          end
        RUBY
        editor.add_table(:b)

        expect(File.read(ignored_path)).to include("tables :a, :b")
      end
    end

    it "accepts a fully-qualified receiver with a leading colon-colon" do
      edit(<<~RUBY) do |editor, ignored_path|
          ::Migrations::Tooling::Schema.ignored do
            tables :a
          end
        RUBY
        editor.add_table(:b)

        expect(File.read(ignored_path)).to include("tables :a, :b")
      end
    end

    it "raises when the block is missing (call without a block)" do
      edit("Migrations::Tooling::Schema.ignored\n") do |editor, ignored_path|
        expect { editor.add_table(:b) }.to raise_error(
          Migrations::Tooling::Schema::ConfigError,
          "Could not find `Migrations::Tooling::Schema.ignored do ... end` in #{ignored_path}",
        )
      end
    end

    it "raises when the message is not `ignored`" do
      edit("Migrations::Tooling::Schema.table :users do\nend\n") do |editor, _ignored_path|
        expect { editor.add_table(:b) }.to raise_error(
          Migrations::Tooling::Schema::ConfigError,
          /Could not find/,
        )
      end
    end

    it "raises when the receiver is not the full constant path" do
      edit("Schema.ignored do\n  tables :a\nend\n") do |editor, _ignored_path|
        expect { editor.add_table(:b) }.to raise_error(
          Migrations::Tooling::Schema::ConfigError,
          /Could not find/,
        )
      end
    end

    it "raises when the receiver is a different constant path" do
      edit("Some::Other::Schema.ignored do\n  tables :a\nend\n") do |editor, _ignored_path|
        expect { editor.add_table(:b) }.to raise_error(
          Migrations::Tooling::Schema::ConfigError,
          /Could not find/,
        )
      end
    end

    it "raises when the receiver is not a constant at all" do
      edit("some_receiver.ignored do\n  tables :a\nend\n") do |editor, _ignored_path|
        expect { editor.add_table(:b) }.to raise_error(
          Migrations::Tooling::Schema::ConfigError,
          /Could not find/,
        )
      end
    end
  end
end

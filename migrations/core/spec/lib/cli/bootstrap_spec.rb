# frozen_string_literal: true

require "colored2"

RSpec.describe Migrations::CLI::Bootstrap do
  describe ".normalize_option_args" do
    subject(:normalized) { described_class.normalize_option_args(argv) }

    context "with the `--opt=value` form" do
      let(:argv) { %w[schema generate --db=intermediate_db] }

      it "splits it into two tokens" do
        expect(normalized).to eq(%w[schema generate --db intermediate_db])
      end
    end

    context "with the `--opt value` form" do
      let(:argv) { %w[schema generate --db intermediate_db] }

      it "leaves it unchanged" do
        expect(normalized).to eq(%w[schema generate --db intermediate_db])
      end
    end

    it "splits only on the first `=`" do
      expect(described_class.normalize_option_args(["--filter=a=b"])).to eq(%w[--filter a=b])
    end

    it "preserves comma-separated values" do
      expect(described_class.normalize_option_args(["--only=users,topics"])).to eq(
        %w[--only users,topics],
      )
    end

    it "splits the shortest long option, where `=` sits right after the flag" do
      expect(described_class.normalize_option_args(["--x=y"])).to eq(%w[--x y])
    end

    it "does not touch short flags, the `--` separator, or bare values" do
      argv = %w[-s=x -- key=value]
      expect(described_class.normalize_option_args(argv)).to eq(argv)
    end

    it "leaves a bare `--=value` untouched" do
      expect(described_class.normalize_option_args(["--=value"])).to eq(["--=value"])
    end
  end

  describe ".deepest_command" do
    let(:node) { Struct.new(:name, :command) }

    it "returns the command itself when nothing is nested under it" do
      leaf = node.new("leaf", nil)
      expect(described_class.deepest_command(leaf).name).to eq("leaf")
    end

    it "walks the nested `command` chain to the deepest sub-command" do
      leaf = node.new("leaf", nil)
      middle = node.new("middle", leaf)
      top = node.new("top", middle)

      expect(described_class.deepest_command(top).name).to eq("leaf")
    end

    it "returns an object that does not respond to `command`" do
      bare = Object.new
      expect(described_class.deepest_command(bare)).to be(bare)
    end
  end

  describe ".build_top_command_class" do
    subject(:top_class) { described_class.build_top_command_class }

    let(:sub_command) do
      Class.new(Migrations::CLI::Command) do
        self.description = "a sub-command"
        def call
        end
      end
    end

    before do
      allow(Migrations::CLI::Registry).to receive(:command_classes).and_return(
        { "sub" => sub_command },
      )
    end

    it "builds a subclass of the CLI base command" do
      expect(top_class.superclass).to be(Migrations::CLI::Command)
    end

    it "describes itself as the migration tools entrypoint" do
      expect(top_class.description).to eq("Discourse migration tools")
    end

    it "nests the registered commands under it" do
      top = top_class.new(["sub"])
      expect(top.command).to be_a(sub_command)
    end

    it "dispatches to the selected sub-command on `call`" do
      top = top_class.new(["sub"])
      command = top.command
      allow(command).to receive(:call)

      top.call

      expect(command).to have_received(:call)
    end

    it "prints usage on `call` when no sub-command was selected" do
      top = top_class.new([])
      allow(top).to receive(:print_usage)

      top.call

      expect(top).to have_received(:print_usage)
    end
  end

  describe ".run" do
    let(:calls) { [] }

    let(:plain_command) do
      recorder = calls
      Class.new(Migrations::CLI::Command) do
        self.description = "a Rails-free command"
        define_method(:call) { recorder << :plain }
      end
    end

    let(:rails_command) do
      recorder = calls
      Class.new(Migrations::CLI::Command) do
        requires_rails!
        self.description = "a command that needs Rails"
        define_method(:call) { recorder << :rails }
      end
    end

    before do
      Migrations::CLI::Registry.reset!
      Migrations::CLI::Registry.register(name: "plain", command_class: plain_command)
      Migrations::CLI::Registry.register(name: "needsrails", command_class: rails_command)
      allow(Migrations).to receive(:load_rails_environment)
    end

    after { Migrations::CLI::Registry.reset! }

    def run_capturing(argv)
      original = $stdout
      $stdout = StringIO.new
      status = nil
      begin
        described_class.run(argv)
      rescue SystemExit => e
        status = e.status
      end
      { output: $stdout.string, status: }
    ensure
      $stdout = original
    end

    it "dispatches to the selected command" do
      described_class.run(%w[plain])
      expect(calls).to eq([:plain])
    end

    it "normalizes `--opt=value` before parsing (Samovar rejects the `=` form on its own)" do
      command_class =
        Class.new(Migrations::CLI::Command) do
          options { option "--db <name>", "the database" }
          def call
            $stdout.puts "PARSED=#{@options[:db]}"
          end
        end
      Migrations::CLI::Registry.register(name: "opt", command_class:)

      result = run_capturing(%w[opt --db=intermediate])

      # Without the normalization the token stays `--db=intermediate`, Samovar
      # fails to parse it, and `run` exits non-zero without ever reaching `call`.
      expect(result[:status]).to be_nil
      expect(result[:output]).to include("PARSED=intermediate")
    end

    it "boots Rails when the selected command requires it" do
      described_class.run(%w[needsrails])

      expect(Migrations).to have_received(:load_rails_environment).with(quiet: true)
      expect(calls).to eq([:rails])
    end

    it "does not boot Rails when the selected command does not require it" do
      described_class.run(%w[plain])

      expect(Migrations).not_to have_received(:load_rails_environment)
    end

    it "does not probe Rails support on a command whose class does not declare it" do
      bare =
        Class.new(Samovar::Command) do
          self.description = "a non-Migrations command"
          def call
          end
        end
      Migrations::CLI::Registry.register(name: "bare", command_class: bare)

      # `Samovar::Command` has no `requires_rails?`; the guard must skip it
      # rather than blow up with a `NoMethodError`.
      expect { described_class.run(%w[bare]) }.not_to raise_error
      expect(Migrations).not_to have_received(:load_rails_environment)
    end

    it "prints the parse error in red, then a blank line and usage, and exits non-zero" do
      result = run_capturing(%w[bogus])

      expect(result[:status]).to eq(1)
      expect(result[:output]).to include("\e[31mCould not parse token \"bogus\"\e[0m")
      expect(result[:output]).to include("\e[0m\n\n")
      expect(result[:output]).to include("Discourse migration tools")
    end

    it "treats a non-`InvalidInputError` Samovar failure as a plain error, not a help request" do
      command_class =
        Class.new(Migrations::CLI::Command) do
          options { option "--name <value>", "a required option", required: true }
          def call
          end
        end
      Migrations::CLI::Registry.register(name: "needsopt", command_class:)

      # A missing required option raises `Samovar::MissingValueError`, which is
      # a `Samovar::Error` but not an `InvalidInputError` and has no `#token`.
      # The guard must keep it out of the help-request path (which would call
      # `e.token` and blow up) and print it as a red error instead.
      result = run_capturing(%w[needsopt])

      expect(result[:status]).to eq(1)
      expect(result[:output]).to include("\e[31mname is required\e[0m")
    end

    it "prints usage and exits zero for `--help`, without the parse-error message" do
      result = run_capturing(%w[--help])

      expect(result[:status]).to eq(0)
      expect(result[:output]).not_to include("Could not parse token")
      expect(result[:output]).to include("Discourse migration tools")
    end

    it "prints usage and exits zero for `-h`, without the parse-error message" do
      result = run_capturing(%w[-h])

      expect(result[:status]).to eq(0)
      expect(result[:output]).not_to include("Could not parse token")
      expect(result[:output]).to include("Discourse migration tools")
    end
  end
end

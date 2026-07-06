# frozen_string_literal: true

RSpec.describe Migrations::CLI::Command do
  describe ".requires_rails?" do
    it "is false for a command that does not opt in" do
      command_class = Class.new(described_class)

      expect(command_class.requires_rails?).to eq(false)
    end

    it "is true once a command declares requires_rails!" do
      command_class = Class.new(described_class) { requires_rails! }

      expect(command_class.requires_rails?).to eq(true)
    end

    it "is inherited by subclasses of a command that opts in" do
      parent = Class.new(described_class) { requires_rails! }
      child = Class.new(parent)

      expect(child.requires_rails?).to eq(true)
    end

    it "stops at the base class instead of raising for a plain command" do
      expect(described_class.requires_rails?).to eq(false)
    end
  end

  describe "STEP_LIST" do
    it "splits a comma-separated value into normalized step names" do
      expect(described_class::STEP_LIST.call("Foo::MyBar,baz")).to eq(%w[my_bar baz])
    end

    it "strips surrounding whitespace from each name" do
      expect(described_class::STEP_LIST.call("  a , b ")).to eq(%w[a b])
    end

    it "returns an empty list for a nil value" do
      expect(described_class::STEP_LIST.call(nil)).to eq([])
    end
  end

  describe "#require_positional!" do
    subject(:command) { described_class.new }

    it "returns the value when it is present" do
      expect(command.send(:require_positional!, "discourse", "converter_type")).to eq("discourse")
    end

    it "raises a presentable error when the value is missing" do
      expect { command.send(:require_positional!, nil, "table_name") }.to raise_error(
        described_class::MissingPositionalError,
        "Missing required argument: <table_name>",
      )
    end

    it "appends the hint to the error message" do
      expect {
        command.send(
          :require_positional!,
          nil,
          "converter_type",
          hint: "Valid names are: discourse",
        )
      }.to raise_error(
        described_class::MissingPositionalError,
        "Missing required argument: <converter_type>\nValid names are: discourse",
      )
    end

    it "does not append a hint line when no hint is given" do
      expect { command.send(:require_positional!, nil, "table_name") }.to raise_error(
        described_class::MissingPositionalError,
        "Missing required argument: <table_name>",
      )
    end

    it "raises an error that the exception handler presents without a backtrace" do
      expect(described_class::MissingPositionalError.ancestors).to include(
        Migrations::CLI::PresentableError,
      )
    end
  end

  describe "option hoisting" do
    let(:command_class) do
      Class.new(described_class) do
        options do
          option "-h/--help", "Print out help."
          option "--settings <path>", "Path of the settings file."
          option "--reset", "Reset before running."
          option "--only <steps>",
                 "Run only the given steps.",
                 default: [],
                 type: Migrations::CLI::Command::STEP_LIST
        end

        one :converter_type, "The converter to run."

        def call
        end
      end
    end

    def hoist(input)
      command_class.new([]).send(:hoist_options, input)
    end

    describe "#hoist_options" do
      it "moves a value-taking option and its value ahead of the positionals" do
        expect(hoist(%w[discourse --only foo])).to eq(%w[--only foo discourse])
      end

      it "keeps trailing positionals after the hoisted option" do
        expect(hoist(%w[discourse --only foo bar])).to eq(%w[--only foo discourse bar])
      end

      it "does not consume the next token for a boolean flag" do
        expect(hoist(%w[discourse --reset])).to eq(%w[--reset discourse])
      end

      it "treats the token after a boolean flag as a positional, not its value" do
        expect(hoist(%w[--reset foo --only x])).to eq(%w[--reset --only x foo])
      end

      it "recognizes options inherited from a parent command" do
        child_class = Class.new(command_class)

        expect(child_class.new([]).send(:hoist_options, %w[discourse --reset])).to eq(
          %w[--reset discourse],
        )
      end

      it "recognizes the long alternative of a flag" do
        expect(hoist(%w[discourse --help])).to eq(%w[--help discourse])
      end

      it "recognizes the short form of a flag" do
        expect(hoist(%w[discourse -h])).to eq(%w[-h discourse])
      end

      it "leaves everything after a -- separator untouched" do
        expect(hoist(%w[discourse -- --only x])).to eq(%w[discourse -- --only x])
      end

      it "does not append a phantom value when a value option is the last token" do
        expect(hoist(%w[discourse --only])).to eq(%w[--only discourse])
      end

      it "treats unrecognized tokens as positionals" do
        expect(hoist(%w[discourse extra])).to eq(%w[discourse extra])
      end

      it "returns the input unchanged when the command declares no options" do
        no_options_class = Class.new(described_class)
        input = %w[discourse --reset]

        expect(no_options_class.new([]).send(:hoist_options, input)).to eq(input)
      end
    end

    describe "#parse" do
      it "parses an option that appears after the positional argument" do
        command = command_class.new(%w[discourse --only a,b])

        expect(command.converter_type).to eq("discourse")
        expect(command.options[:only]).to eq(%w[a b])
      end
    end
  end
end

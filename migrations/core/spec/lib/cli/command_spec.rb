# frozen_string_literal: true

RSpec.describe Migrations::CLI::Command do
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

    it "raises an error that the exception handler presents without a backtrace" do
      expect(described_class::MissingPositionalError.ancestors).to include(
        Migrations::CLI::PresentableError,
      )
    end
  end
end

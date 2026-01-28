# frozen_string_literal: true

RSpec.describe Migrations::Core::CLI::Application do
  describe ".register" do
    it "registers a command" do
      test_command = Class.new(Migrations::Core::CLI::Command)
      described_class.register("test_cmd", test_command)

      expect(described_class.commands["test_cmd"]).to eq(test_command)
    ensure
      described_class.commands.delete("test_cmd")
    end
  end

  describe ".commands" do
    it "returns the registered commands hash" do
      expect(described_class.commands).to be_a(Hash)
    end
  end
end

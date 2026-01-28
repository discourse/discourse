# frozen_string_literal: true

RSpec.describe Migrations::Tooling::CLI::Commands::Generate do
  it "is registered with the CLI application" do
    expect(Migrations::Core::CLI::Application.commands["generate"]).to eq(described_class)
  end

  describe ".description" do
    it "has a description" do
      expect(described_class.description).to eq("Generate scaffolds")
    end
  end
end

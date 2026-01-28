# frozen_string_literal: true

RSpec.describe Migrations::Tooling::CLI::Commands::Schema do
  it "is registered with the CLI application" do
    expect(Migrations::Core::CLI::Application.commands["schema"]).to eq(described_class)
  end

  describe ".description" do
    it "has a description" do
      expect(described_class.description).to eq("Schema management commands")
    end
  end
end

# frozen_string_literal: true

RSpec.describe JsonApiKit::VersionChange::PassThrough do
  subject(:pass_through) { described_class.new(name) }

  let(:name) { JsonApiKit::Name::Field.new(value: "title", type: "topics") }

  describe "#current" do
    it "returns the name" do
      expect(pass_through.current).to eq(name)
    end
  end

  describe "#current_pairs" do
    it "returns the name with its value" do
      expect(pass_through.current_pairs(name => "A")).to eq([[name, "A"]])
    end
  end

  describe "#previous_names" do
    it "returns the name" do
      expect(pass_through.previous_names).to eq([name])
    end
  end

  describe "#previous_pairs" do
    it "returns the name with the value" do
      expect(pass_through.previous_pairs("A")).to eq([[name, "A"]])
    end
  end
end

# frozen_string_literal: true

RSpec.describe Migrations::Converters::Base do
  after { Migrations::Converters::Registry.clear }

  describe ".inherited" do
    it "registers subclasses with the registry" do
      test_converter = Class.new(described_class)

      expect(Migrations::Converters::Registry.converters).to include(test_converter)
    end
  end

  describe "#run" do
    it "raises NotImplementedError" do
      converter = described_class.new
      expect { converter.run }.to raise_error(NotImplementedError)
    end
  end
end

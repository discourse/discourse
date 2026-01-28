# frozen_string_literal: true

RSpec.describe Migrations::Converters do
  describe "VERSION" do
    it "has a version number" do
      expect(Migrations::Converters::VERSION).not_to be_nil
    end
  end

  describe ".root" do
    it "returns the gem root path" do
      expect(Migrations::Converters.root).to end_with("migrations/converters")
    end
  end
end

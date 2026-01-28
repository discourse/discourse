# frozen_string_literal: true

RSpec.describe Migrations::Core do
  describe "VERSION" do
    it "has a version number" do
      expect(Migrations::Core::VERSION).not_to be_nil
    end
  end

  describe ".root" do
    it "returns the gem root path" do
      expect(Migrations::Core.root).to end_with("migrations/core")
    end
  end
end

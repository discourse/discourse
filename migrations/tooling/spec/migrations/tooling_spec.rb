# frozen_string_literal: true

RSpec.describe Migrations::Tooling do
  describe "VERSION" do
    it "has a version number" do
      expect(Migrations::Tooling::VERSION).not_to be_nil
    end
  end

  describe ".root" do
    it "returns the gem root path" do
      expect(Migrations::Tooling.root).to end_with("migrations/tooling")
    end
  end
end

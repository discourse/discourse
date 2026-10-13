# frozen_string_literal: true

RSpec.describe NavigationDestination do
  describe "#initialize" do
    it "rejects external, dynamic, and ambiguous paths" do
      [
        "https://example.com",
        "//example.com",
        "/\\example.com",
        "/users/:id",
        "/../admin",
        "/admin?redirect=elsewhere",
      ].each do |path|
        expect {
          described_class.new(id: "test", path: path, title: "title", description: "description") do
            true
          end
        }.to raise_error(ArgumentError)
      end
    end

    it "requires an explicit availability predicate" do
      expect {
        described_class.new(id: "test", path: "/admin", title: "title", description: "description")
      }.to raise_error(ArgumentError, /availability/)
    end
  end
end

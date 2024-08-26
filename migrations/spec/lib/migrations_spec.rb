# frozen_string_literal: true

RSpec.describe ::Migrations do
  describe ".root_path" do
    it "returns the root path" do
      expect(described_class.root_path).to eq(File.expand_path("../..", __dir__))
    end
  end
end

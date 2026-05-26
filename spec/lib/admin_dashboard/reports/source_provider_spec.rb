# frozen_string_literal: true

RSpec.describe AdminDashboard::Reports::SourceProvider do
  describe ".accessible_ids" do
    let(:provider) do
      Class.new(described_class) do
        def self.source_name = "test"

        def self.label = "Test"

        def self.resolve_many(identifiers, guardian:)
          identifiers
            .select { |id| %w[a b].include?(id) }
            .each_with_object({}) do |id, hash|
              hash[id] = AdminDashboard::Reports::ResolvedReport.new(
                source: source_name,
                identifier: id,
                title: id,
                description: nil,
                label: label,
                url: nil,
              )
            end
        end
      end
    end

    it "returns the set of identifiers that resolve_many returned" do
      result = provider.accessible_ids(%w[a b c], guardian: nil)
      expect(result).to eq(Set.new(%w[a b]))
    end

    it "returns an empty set when nothing resolves" do
      result = provider.accessible_ids(%w[x y z], guardian: nil)
      expect(result).to be_empty
    end
  end
end

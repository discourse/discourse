# frozen_string_literal: true

RSpec.describe Migrations::Tooling::Coverage::SchemaColumns do
  describe ".call" do
    subject(:models) { described_class.call }

    it "includes generated models keyed by their constant name" do
      expect(models).to include("User", "Badge", "UserCustomField")
    end

    it "excludes manual (hand-written) models" do
      expect(models).not_to include("Upload", "LogEntry")
    end

    it "splits required and optional columns from the create signature" do
      user = models.fetch("User")

      expect(user.required).to include(:original_id, :username, :created_at, :trust_level)
      expect(user.optional).to include(:active, :name)
      expect(user.required).not_to include(:active)
    end

    it "exposes all columns and the table name for a model" do
      badge = models.fetch("Badge")

      expect(badge.columns).to include(:original_id, :name)
      expect(badge.table_name).to eq("badges")
    end
  end
end

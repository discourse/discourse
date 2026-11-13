# frozen_string_literal: true

RSpec.describe DirectoryColumn do
  describe ".find_or_create_plugin_directory_column" do
    let(:attrs) { { column_name: "yak_count", icon: "cow", query: "SELECT 1" } }

    before { DirectoryItem.clear_plugin_queries }

    after { DirectoryColumn.clear_plugin_directory_columns }

    it "positions the column after the highest existing position" do
      # Drop the lazily seeded automatic columns so the explicit row below is
      # the highest position on every database, not just unseeded ones.
      described_class.delete_all
      DirectoryColumn.create!(name: "topics_entered", enabled: true, position: 3)

      described_class.find_or_create_plugin_directory_column(**attrs)

      expect(described_class.find_by(name: "yak_count").position).to eq(4)
    end

    it "starts at position 1 when no directory columns exist yet" do
      # Automatic columns are seeded lazily, so plugins can register before
      # any column exists.
      described_class.delete_all

      described_class.find_or_create_plugin_directory_column(**attrs)

      expect(described_class.find_by(name: "yak_count").position).to eq(1)
    end
  end
end

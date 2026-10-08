# frozen_string_literal: true

RSpec.describe Migrations::NameNormalizer do
  it "composes and downcases" do
    expect(described_class.normalize("Café")).to eq("café")
  end

  it "preserves the distinct sigma identity keys used by core" do
    expect(%w[ΚΟΣΜΟΣ κοσμος κοσμοσ].map { |name| described_class.normalize(name) }).to eq(
      %w[κοσμοσ κοσμος κοσμοσ],
    )
  end
end

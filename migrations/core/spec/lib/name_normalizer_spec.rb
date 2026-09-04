# frozen_string_literal: true

RSpec.describe Migrations::NameNormalizer do
  it "composes and downcases" do
    expect(described_class.normalize("Café")).to eq("café")
  end

  it "folds a word-final capital sigma the same way as the lowercase medial one" do
    # JavaScript lowercases the final Σ to ς, Ruby to σ; both sides must meet.
    expect(described_class.normalize("ΟΔΥΣΣΕΥΣ")).to eq(described_class.normalize("οδυσσευς"))
  end
end

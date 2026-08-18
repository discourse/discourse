# frozen_string_literal: true

RSpec.describe Migrations::SortedStringSet do
  it "handles an empty set" do
    set = described_class.new([])

    expect(set).to be_empty
    expect(set.size).to eq(0)
    expect(set.include?("anything")).to be false
  end

  it "handles a single entry" do
    set = described_class.new(["alice"])

    expect(set).not_to be_empty
    expect(set.size).to eq(1)
    expect(set.include?("alice")).to be true
    expect(set.include?("bob")).to be false
  end

  it "answers membership hits and misses" do
    set = described_class.new(%w[carol alice bob dave])

    expect(set.size).to eq(4)
    expect(set.include?("alice")).to be true
    expect(set.include?("bob")).to be true
    expect(set.include?("carol")).to be true
    expect(set.include?("dave")).to be true
    expect(set.include?("erin")).to be false
    expect(set.include?("")).to be false
  end

  it "does not match a strict prefix of a stored name, or a name a stored one is a prefix of" do
    set = described_class.new(["alice"])

    expect(set.include?("ali")).to be false
    expect(set.include?("alicent")).to be false
  end

  it "misses a name sorting before the first entry and one sorting after the last" do
    set = described_class.new(%w[bob carol dave])

    expect(set.include?("aaron")).to be false
    expect(set.include?("zoe")).to be false
  end

  it "matches the exact first and last boundary entries" do
    set = described_class.new(%w[bob carol dave])

    expect(set.include?("bob")).to be true
    expect(set.include?("dave")).to be true
  end

  it "stores and matches unicode names" do
    set = described_class.new(%w[café 田中 josé_team])

    expect(set.include?("café")).to be true
    expect(set.include?("田中")).to be true
    expect(set.include?("josé_team")).to be true
    expect(set.include?("cafe")).to be false
  end

  it "dedupes duplicate inputs" do
    set = described_class.new(%w[alice alice bob alice bob])

    expect(set.size).to eq(2)
    expect(set.include?("alice")).to be true
    expect(set.include?("bob")).to be true
  end
end

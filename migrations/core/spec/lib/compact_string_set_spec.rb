# frozen_string_literal: true

RSpec.describe Migrations::CompactStringSet do
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

  it "answers correctly across probe-table growth" do
    names = Array.new(5_000) { |i| "user_#{i}" }
    set = described_class.new(names)

    expect(set.size).to eq(5_000)
    expect(names.all? { |name| set.include?(name) }).to be true
    expect(set.include?("user_5000")).to be false
    expect(set.include?("user")).to be false
  end

  it "consumes a streaming enumerable once, without materializing it" do
    passes = 0
    names =
      Enumerator.new do |yielder|
        passes += 1
        1_000.times { |i| yielder << "name_#{i}" }
      end

    set = described_class.new(names)

    expect(passes).to eq(1)
    expect(set.size).to eq(1_000)
    expect(set.include?("name_999")).to be true
  end

  it "matches a query produced as a byteslice of a larger string" do
    set = described_class.new(["bob"])
    query = "say @bob now".byteslice(5, 3)

    expect(set.include?(query)).to be true
  end
end

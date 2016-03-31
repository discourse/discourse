require 'rails_helper'
require 'email'

describe Enum do
  let(:array_enum) { Enum.new(:jake, :finn, :princess_bubblegum, :peppermint_butler) }
  let(:hash_enum) { Enum.new(jake: 1, finn: 2, princess_bubblegum: 3, peppermint_butler: 4) }

  describe ".[]" do
    it "looks up a number by symbol" do
      expect(array_enum[:princess_bubblegum]).to eq(3)
      expect(hash_enum[:princess_bubblegum]).to eq(3)
    end

    it "looks up a symbol by number" do
      expect(array_enum[2]).to eq(:finn)
      expect(hash_enum[2]).to eq(:finn)
    end
  end

  describe ".valid?" do
    it "returns true if a key exists" do
      expect(array_enum.valid?(:finn)).to eq(true)
      expect(hash_enum.valid?(:finn)).to eq(true)
    end

    it "returns false if a key does not exist" do
      expect(array_enum.valid?(:obama)).to eq(false)
      expect(hash_enum.valid?(:obama)).to eq(false)
    end
  end

  describe ".only" do
    it "returns only the values we ask for" do
      expect(array_enum.only(:jake, :princess_bubblegum)).to eq({ jake: 1, princess_bubblegum: 3 })
      expect(hash_enum.only(:jake, :princess_bubblegum)).to eq({ jake: 1, princess_bubblegum: 3 })
    end
  end

  describe ".except" do
    it "returns everything but the values we ask to delete" do
      expect(array_enum.except(:jake, :princess_bubblegum)).to eq({ finn: 2, peppermint_butler: 4 })
      expect(hash_enum.except(:jake, :princess_bubblegum)).to eq({ finn: 2, peppermint_butler: 4 })
    end
  end

  context "allows to specify number of first enum member" do
    it "number of first enum member should be 0 " do
      start_enum = Enum.new(:jake, :finn, :princess_bubblegum, :peppermint_butler, start: 0)
      expect(start_enum[:princess_bubblegum]).to eq(2)
    end
  end
end

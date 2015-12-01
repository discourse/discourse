require 'rails_helper'
require 'email'

describe Enum do
  let(:enum) { Enum.new(:jake, :finn, :princess_bubblegum, :peppermint_butler) }

  describe ".[]" do
    it "looks up a number by symbol" do
      expect(enum[:princess_bubblegum]).to eq(3)
    end

    it "looks up a symbol by number" do
      expect(enum[2]).to eq(:finn)
    end
  end

  describe ".valid?" do
    it "returns true if a key exists" do
      expect(enum.valid?(:finn)).to eq(true)
    end

    it "returns false if a key does not exist" do
      expect(enum.valid?(:obama)).to eq(false)
    end
  end

  describe ".only" do
    it "returns only the values we ask for" do
      expect(enum.only(:jake, :princess_bubblegum)).to eq({ jake: 1, princess_bubblegum: 3 })
    end
  end

  describe ".except" do
    it "returns everything but the values we ask to delete" do
      expect(enum.except(:jake, :princess_bubblegum)).to eq({ finn: 2, peppermint_butler: 4 })
    end
  end
end

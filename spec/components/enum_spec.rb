require 'spec_helper'
require 'email'

describe Enum do
  let(:enum) { Enum.new(:jake, :finn, :princess_bubblegum, :peppermint_butler) }

  describe ".[]" do
    it "looks up a number by symbol" do
      enum[:princess_bubblegum].should == 3
    end

    it "looks up a symbol by number" do
      enum[2].should == :finn
    end
  end

  describe ".valid?" do
    it "returns true if a key exists" do
      enum.valid?(:finn).should be_true
    end

    it "returns false if a key does not exist" do
      enum.valid?(:obama).should be_false
    end
  end

  describe ".only" do
    it "returns only the values we ask for" do
      enum.only(:jake, :princess_bubblegum).should == { jake: 1, princess_bubblegum: 3 }
    end
  end

  describe ".except" do
    it "returns everything but the values we ask to delete" do
      enum.except(:jake, :princess_bubblegum).should == { finn: 2, peppermint_butler: 4 }
    end
  end
end

require 'spec_helper'
require 'email'

describe Enum do

  let(:enum) { Enum.new(:jake, :finn, :princess_bubblegum, :peppermint_butler) }

  context ".[]" do
    it "allows us to look up a number by symbol" do
      enum[:princess_bubblegum].should == 3
    end

    it "allows us to look up a symbol by number" do
      enum[2].should == :finn
    end
  end

  context ".valid?" do
    it "returns true for a value that exists" do
      enum.valid?(4).should be_false
    end

    it "returns true for a key that doesn't exist" do
      enum.valid?(:ice_king).should be_false
    end
  end

  context ".only" do
    it "returns only the values we ask for" do
      enum.only(:jake, :princess_bubblegum).should == {jake: 1, princess_bubblegum: 3}
    end
  end

  context ".except" do
    it "doesn't return the values we don't want" do
      enum.except(:jake, :princess_bubblegum).should == {finn: 2, peppermint_butler: 4}
    end
  end

end

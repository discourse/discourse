require 'rails_helper'
require 'onpdiff'

describe ONPDiff do

  describe "diff" do

    it "returns an empty array when there is no content to diff" do
      expect(ONPDiff.new("", "").diff).to eq([])
    end

    it "returns an array with the operation code for each element" do
      expect(ONPDiff.new("abcd", "abef").diff).to eq([["a", :common], ["b", :common], ["e", :add], ["f", :add], ["c", :delete], ["d", :delete]])
    end

  end

  describe "short_diff" do

    it "returns an empty array when there is no content to diff" do
      expect(ONPDiff.new("", "").short_diff).to eq([])
    end

    it "returns an array with the operation code for each element" do
      expect(ONPDiff.new("abc", "acd").short_diff).to eq([["a", :common], ["b", :delete], ["c", :common], ["d", :add]])
    end

    it "returns an array with sequencially similar operations merged" do
      expect(ONPDiff.new("abcd", "abef").short_diff).to eq([["ab", :common], ["ef", :add], ["cd", :delete]])
    end

  end

end


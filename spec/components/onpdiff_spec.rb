# frozen_string_literal: true

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

    it "bails out on large diffs" do
      a = SecureRandom.alphanumeric(5_000)
      b = SecureRandom.alphanumeric(5_000)
      expect(ONPDiff.new(a, b).diff).to eq([])
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

  describe "paragraph_diff" do

    it "returns an empty array when there is no content to diff" do
      expect(ONPDiff.new("", "").paragraph_diff).to eq([])
    end

    it "returns an array with the operation code for each element" do
      expect(ONPDiff.new("abc", "acd").paragraph_diff).to eq([["a", :common], ["b", :delete], ["c", :common], ["d", :add]])
    end

    it "pairs as many elements as possible" do
      expect(ONPDiff.new("abcd", "abef").paragraph_diff).to eq([
        ["a", :common], ["b", :common],
        ["e", :add], ["c", :delete],
        ["f", :add], ["d", :delete]
      ])

      expect(ONPDiff.new("abcde", "abfg").paragraph_diff).to eq([
        ["a", :common], ["b", :common],
        ["c", :delete],
        ["d", :delete], ["f", :add],
        ["e", :delete], ["g", :add]
      ])

      expect(ONPDiff.new("abcd", "abefg").paragraph_diff).to eq([
        ["a", :common], ["b", :common],
        ["e", :add],
        ["f", :add], ["c", :delete],
        ["g", :add], ["d", :delete]
      ])
    end

  end

end

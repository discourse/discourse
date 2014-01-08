require 'spec_helper'
require 'onpdiff'

describe ONPDiff do

  describe "diff" do

    it "returns an empty array when there is no content to diff" do
      ONPDiff.new("", "").diff.should == []
    end

    it "returns an array with the operation code for each element" do
      ONPDiff.new("abcd", "abef").diff.should == [["a", :common], ["b", :common], ["e", :add], ["f", :add], ["c", :delete], ["d", :delete]]
    end

  end

  describe "short_diff" do

    it "returns an empty array when there is no content to diff" do
      ONPDiff.new("", "").short_diff.should == []
    end

    it "returns an array with the operation code for each element" do
      ONPDiff.new("abc", "acd").short_diff.should == [["a", :common], ["b", :delete], ["c", :common], ["d", :add]]
    end

    it "returns an array with sequencially similar operations merged" do
      ONPDiff.new("abcd", "abef").short_diff.should == [["ab", :common], ["ef", :add], ["cd", :delete]]
    end

  end

end


require 'spec_helper'
require 'summarize'

describe Summarize do

  it "is blank when the input is nil" do
    Summarize.new(nil).summary.should be_blank
  end

  it "is blank when the input is an empty string" do
    Summarize.new("").summary.should be_blank
  end

  it "removes html tags" do
    Summarize.new("hello <b>robin</b>").summary.should == "hello robin"
  end

  it "strips leading and trailing space" do
    Summarize.new("\t  \t hello   \t ").summary.should == "hello"
  end

  it "trims long strings and adds an ellipsis" do
    Summarize.stubs(:max_length).returns(11)
    Summarize.new("discourse is a cool forum").summary.should == "discourse is..."
  end

end

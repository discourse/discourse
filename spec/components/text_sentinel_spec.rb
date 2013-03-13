# encoding: utf-8

require 'spec_helper'
require 'text_sentinel'

describe TextSentinel do


  context "entropy" do


    it "returns 0 for an empty string" do
      TextSentinel.new("").entropy.should == 0
    end

    it "returns 0 for a nil string" do
      TextSentinel.new(nil).entropy.should == 0
    end

    it "returns 1 for a string with many leading spaces" do
      TextSentinel.new((" " * 10) + "x").entropy.should == 1
    end

    it "returns 1 for one char, even repeated" do
      TextSentinel.new("a" * 10).entropy.should == 1
    end

    it "returns an accurate count of many chars" do
      TextSentinel.new("evil trout is evil").entropy.should == 10
    end

    it "Works on foreign characters" do
      TextSentinel.new("去年十社會警告").entropy.should == 7
    end

  end

  context "cleaning up" do

    it "allows utf-8 chars" do
      TextSentinel.new("йȝîûηыეமிᚉ⠛").text.should == "йȝîûηыეமிᚉ⠛"
    end

    context "interior spaces" do

      let(:spacey_string) { "hello     there's weird     spaces here." }
      let(:unspacey_string) { "hello there's weird spaces here." }

      it "ignores intra spaces by default" do
        TextSentinel.new(spacey_string).text.should == spacey_string
      end

      it "fixes intra spaces when enabled" do
        TextSentinel.new(spacey_string, remove_interior_spaces: true).text.should == unspacey_string
      end

      it "fixes intra spaces in titles" do
        TextSentinel.title_sentinel(spacey_string).text.should == unspacey_string
      end

    end

    context "stripping whitespace" do
      let(:spacey_string) { "   \t  test \t  " }
      let(:unspacey_string) { "test" }

      it "does not strip leading and trailing whitespace by default" do
        TextSentinel.new(spacey_string).text.should == spacey_string
      end

      it "strips leading and trailing whitespace when enabled" do
        TextSentinel.new(spacey_string, strip: true).text.should == unspacey_string
      end

      it "strips leading and trailing whitespace in titles" do
        TextSentinel.title_sentinel(spacey_string).text.should == unspacey_string
      end
    end

  end

  context "validity" do

    let(:valid_string) { "This is a cool topic about Discourse" }

    it "allows a valid string" do
      TextSentinel.new(valid_string).should be_valid
    end

    it "doesn't allow all caps topics" do
      TextSentinel.new(valid_string.upcase).should_not be_valid
    end

    it "enforces the minimum entropy" do
      TextSentinel.new(valid_string, min_entropy: 16).should be_valid
    end

    it "enforces the minimum entropy" do
      TextSentinel.new(valid_string, min_entropy: 17).should_not be_valid
    end

    it "allows all foreign characters" do
      TextSentinel.new("去年十二月，北韓不顧國際社會警告").should be_valid
    end

    it "doesn't allow a long alphanumeric string with no spaces" do
      TextSentinel.new("jfewjfoejwfojeojfoejofjeo3" * 5, max_word_length: 30).should_not be_valid
    end

    it "doesn't except junk symbols as a string" do
      TextSentinel.new("[[[").should_not be_valid
      TextSentinel.new("<<<").should_not be_valid
      TextSentinel.new("{{$!").should_not be_valid
    end


  end


end

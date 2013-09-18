# encoding: utf-8

require 'spec_helper'
require 'text_sentinel'

describe TextSentinel do

  it "allows utf-8 chars" do
    TextSentinel.new("йȝîûηыეமிᚉ⠛").text.should == "йȝîûηыეமிᚉ⠛"
  end

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
      TextSentinel.new("去年十社會警告").entropy.should == 19
    end

    it "generates enough entropy for short foreign strings" do
      TextSentinel.new("又一个测").entropy.should == 11
    end

    it "handles repeated foreign characters" do
      TextSentinel.new("又一个测试话题" * 3).entropy.should == 18
    end

  end

  context 'body_sentinel' do
    [ 'evil trout is evil',
      "去年十社會警告",
      "P.S. Пробирочка очень толковая и весьма умная, так что не обнимайтесь.",
      "LOOK: 去年十社會警告"
    ].each do |valid_body|
      it "handles a valid body in a private message" do
        expect(TextSentinel.body_sentinel(valid_body, private_message: true)).to be_valid
      end

      it "handles a valid body in a public post" do
        expect(TextSentinel.body_sentinel(valid_body, private_message: false)).to be_valid
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

    it "doesn't accept junk symbols as a string" do
      TextSentinel.new("[[[").should_not be_valid
      TextSentinel.new("<<<").should_not be_valid
      TextSentinel.new("{{$!").should_not be_valid
    end

    it "does allow a long alphanumeric string joined with slashes" do
      TextSentinel.new("gdfgdfgdfg/fgdfgdfgdg/dfgdfgdfgd/dfgdfgdfgf", max_word_length: 30).should be_valid
    end

    it "does allow a long alphanumeric string joined with dashes" do
      TextSentinel.new("gdfgdfgdfg-fgdfgdfgdg-dfgdfgdfgd-dfgdfgdfgf", max_word_length: 30).should be_valid
    end

  end

  context 'title_sentinel' do

    it "uses a sensible min entropy value when min title length is less than title_min_entropy" do
      SiteSetting.stubs(:min_topic_title_length).returns(3)
      SiteSetting.stubs(:title_min_entropy).returns(10)
      TextSentinel.title_sentinel('Hey').should be_valid
    end

  end

  context 'body_sentinel' do

    it "uses a sensible min entropy value when min body length is less than min entropy" do
      SiteSetting.stubs(:min_post_length).returns(3)
      SiteSetting.stubs(:body_min_entropy).returns(7)
      TextSentinel.body_sentinel('Yup').should be_valid
    end

    it "uses a sensible min entropy value when min pm body length is less than min entropy" do
      SiteSetting.stubs(:min_post_length).returns(5)
      SiteSetting.stubs(:min_private_message_post_length).returns(3)
      SiteSetting.stubs(:body_min_entropy).returns(7)
      TextSentinel.body_sentinel('Lol', private_message: true).should be_valid
    end
  end

end

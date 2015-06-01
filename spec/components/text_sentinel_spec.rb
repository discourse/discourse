# encoding: utf-8

require 'spec_helper'
require 'text_sentinel'

describe TextSentinel do

  it "allows utf-8 chars" do
    expect(TextSentinel.new("йȝîûηыეமிᚉ⠛").text).to eq("йȝîûηыეமிᚉ⠛")
  end

  context "entropy" do

    it "returns 0 for an empty string" do
      expect(TextSentinel.new("").entropy).to eq(0)
    end

    it "returns 0 for a nil string" do
      expect(TextSentinel.new(nil).entropy).to eq(0)
    end

    it "returns 1 for a string with many leading spaces" do
      expect(TextSentinel.new((" " * 10) + "x").entropy).to eq(1)
    end

    it "returns 1 for one char, even repeated" do
      expect(TextSentinel.new("a" * 10).entropy).to eq(1)
    end

    it "returns an accurate count of many chars" do
      expect(TextSentinel.new("evil trout is evil").entropy).to eq(10)
    end

    it "Works on foreign characters" do
      expect(TextSentinel.new("去年十社會警告").entropy).to eq(19)
    end

    it "generates enough entropy for short foreign strings" do
      expect(TextSentinel.new("又一个测").entropy).to eq(11)
    end

    it "handles repeated foreign characters" do
      expect(TextSentinel.new("又一个测试话题" * 3).entropy).to eq(18)
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
      expect(TextSentinel.new(valid_string)).to be_valid
    end

    it "doesn't allow all caps topics" do
      expect(TextSentinel.new(valid_string.upcase)).not_to be_valid
    end

    it "enforces the minimum entropy" do
      expect(TextSentinel.new(valid_string, min_entropy: 16)).to be_valid
    end

    it "enforces the minimum entropy" do
      expect(TextSentinel.new(valid_string, min_entropy: 17)).not_to be_valid
    end

    it "allows all foreign characters" do
      expect(TextSentinel.new("去年十二月，北韓不顧國際社會警告")).to be_valid
    end

    it "doesn't allow a long alphanumeric string with no spaces" do
      expect(TextSentinel.new("jfewjfoejwfojeojfoejofjeo3" * 5, max_word_length: 30)).not_to be_valid
    end

    it "doesn't accept junk symbols as a string" do
      expect(TextSentinel.new("[[[")).not_to be_valid
      expect(TextSentinel.new("<<<")).not_to be_valid
      expect(TextSentinel.new("{{$!")).not_to be_valid
    end

    it "does allow a long alphanumeric string joined with slashes" do
      expect(TextSentinel.new("gdfgdfgdfg/fgdfgdfgdg/dfgdfgdfgd/dfgdfgdfgf", max_word_length: 30)).to be_valid
    end

    it "does allow a long alphanumeric string joined with dashes" do
      expect(TextSentinel.new("gdfgdfgdfg-fgdfgdfgdg-dfgdfgdfgd-dfgdfgdfgf", max_word_length: 30)).to be_valid
    end

    it "allows a long string with periods" do
      expect(TextSentinel.new("error in org.gradle.internal.graph.CachingDirectedGraphWalker", max_word_length: 30)).to be_valid
    end

  end

  context 'title_sentinel' do

    it "uses a sensible min entropy value when min title length is less than title_min_entropy" do
      SiteSetting.stubs(:min_topic_title_length).returns(3)
      SiteSetting.stubs(:title_min_entropy).returns(10)
      expect(TextSentinel.title_sentinel('Hey')).to be_valid
    end

  end

  context 'body_sentinel' do

    it "uses a sensible min entropy value when min body length is less than min entropy" do
      SiteSetting.stubs(:min_post_length).returns(3)
      SiteSetting.stubs(:body_min_entropy).returns(7)
      expect(TextSentinel.body_sentinel('Yup')).to be_valid
    end

    it "uses a sensible min entropy value when min pm body length is less than min entropy" do
      SiteSetting.stubs(:min_post_length).returns(5)
      SiteSetting.stubs(:min_private_message_post_length).returns(3)
      SiteSetting.stubs(:body_min_entropy).returns(7)
      expect(TextSentinel.body_sentinel('Lol', private_message: true)).to be_valid
    end
  end

end

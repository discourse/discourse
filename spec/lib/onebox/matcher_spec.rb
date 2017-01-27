require "spec_helper"

class TestEngine
  def self.===(uri)
    true
  end
end

describe Onebox::Matcher do

  describe "oneboxed" do

    describe "with a path" do
      let(:url) { "http://party.time.made.up-url.com/beep/boop" }
      let(:matcher) { Onebox::Matcher.new(url) }

      it "finds an engine" do
        matcher.stubs(:ordered_engines).returns([TestEngine])
        expect(matcher.oneboxed).not_to be_nil
      end
    end

    describe "without a path" do
      let(:url) { "http://party.time.made.up-url.com/" }
      let(:matcher) { Onebox::Matcher.new(url) }

      it "doesn't find an engine" do
        matcher.stubs(:ordered_engines).returns([TestEngine])
        expect(matcher.oneboxed).not_to be_nil
      end
    end

    describe "without a path but has a query string" do
      let(:url) { "http://party.time.made.up-url.com/?article_id=1234" }
      let(:matcher) { Onebox::Matcher.new(url) }

      it "finds an engine" do
        matcher.stubs(:ordered_engines).returns([TestEngine])
        expect(matcher.oneboxed).not_to be_nil
      end
    end

    describe "without a path but has a fragment string" do
      let(:url) { "http://party.time.made.up-url.com/#article_id=1234" }
      let(:matcher) { Onebox::Matcher.new(url) }

      it "finds an engine" do
        matcher.stubs(:ordered_engines).returns([TestEngine])
        expect(matcher.oneboxed).not_to be_nil
      end
    end

    describe "with a whitelisted port/scheme" do
      %w{http://example.com https://example.com http://example.com:80 //example.com}.each do |url|
        it "finds an engine for '#{url}'" do
          matcher = Onebox::Matcher.new(url)
          matcher.stubs(:ordered_engines).returns([TestEngine])
          expect(matcher.oneboxed).not_to be_nil
        end
      end
    end

    describe "without a whitelisted port/scheme" do
      %w{http://example.com:21 ftp://example.com}.each do |url|
        it "doesn't find an engine for '#{url}'" do
          matcher = Onebox::Matcher.new(url)
          matcher.stubs(:ordered_engines).returns([TestEngine])
          expect(matcher.oneboxed).to be_nil
        end
      end
    end

  end
end

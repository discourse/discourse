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
        matcher.oneboxed.should_not be_nil
      end
    end

    describe "without a path" do
      let(:url) { "http://party.time.made.up-url.com/" }
      let(:matcher) { Onebox::Matcher.new(url) }

      it "doesn't find an engine" do
        matcher.stubs(:ordered_engines).returns([TestEngine])
        matcher.oneboxed.should be_nil
      end
    end

    describe "without a path but has a query string" do
      let(:url) { "http://party.time.made.up-url.com/?article_id=1234" }
      let(:matcher) { Onebox::Matcher.new(url) }

      it "it finds an engine" do
        matcher.stubs(:ordered_engines).returns([TestEngine])
        matcher.oneboxed.should_not be_nil
      end
    end
  end
end

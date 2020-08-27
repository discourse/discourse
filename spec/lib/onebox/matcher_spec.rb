# frozen_string_literal: true

require "spec_helper"

class TestEngine
  def self.===(uri)
    true
  end

  def self.iframe_origins
    ["https://example.com", "https://example2.com"]
  end
end

describe Onebox::Matcher do
  let(:opts) { { allowed_iframe_regexes: [/.*/] } }
  describe "oneboxed" do

    describe "with a path" do
      let(:url) { "http://party.time.made.up-url.com/beep/boop" }
      let(:matcher) { Onebox::Matcher.new(url, opts) }

      it "finds an engine" do
        allow(matcher).to receive(:ordered_engines).and_return([TestEngine])
        expect(matcher.oneboxed).not_to be_nil
      end
    end

    describe "without a path" do
      let(:url) { "http://party.time.made.up-url.com/" }
      let(:matcher) { Onebox::Matcher.new(url, opts) }

      it "doesn't find an engine" do
        allow(matcher).to receive(:ordered_engines).and_return([TestEngine])
        expect(matcher.oneboxed).not_to be_nil
      end
    end

    describe "without a path but has a query string" do
      let(:url) { "http://party.time.made.up-url.com/?article_id=1234" }
      let(:matcher) { Onebox::Matcher.new(url, opts) }

      it "finds an engine" do
        allow(matcher).to receive(:ordered_engines).and_return([TestEngine])
        expect(matcher.oneboxed).not_to be_nil
      end
    end

    describe "without a path but has a fragment string" do
      let(:url) { "http://party.time.made.up-url.com/#article_id=1234" }
      let(:matcher) { Onebox::Matcher.new(url, opts) }

      it "finds an engine" do
        allow(matcher).to receive(:ordered_engines).and_return([TestEngine])
        expect(matcher.oneboxed).not_to be_nil
      end
    end

    describe "with a allowlisted port/scheme" do
      %w{http://example.com https://example.com http://example.com:80 //example.com}.each do |url|
        it "finds an engine for '#{url}'" do
          matcher = Onebox::Matcher.new(url, opts)
          allow(matcher).to receive(:ordered_engines).and_return([TestEngine])
          expect(matcher.oneboxed).not_to be_nil
        end
      end
    end

    describe "without a allowlisted port/scheme" do
      %w{http://example.com:21 ftp://example.com}.each do |url|
        it "doesn't find an engine for '#{url}'" do
          matcher = Onebox::Matcher.new(url, opts)
          allow(matcher).to receive(:ordered_engines).and_return([TestEngine])
          expect(matcher.oneboxed).to be_nil
        end
      end
    end

    describe "with restricted iframe domains" do
      it "finds an engine when wildcard allowed" do
        matcher = Onebox::Matcher.new("https://example.com", allowed_iframe_regexes: [/.*/])
        allow(matcher).to receive(:ordered_engines).and_return([TestEngine])
        expect(matcher.oneboxed).not_to be_nil
      end

      it "doesn't find an engine when nothing allowed" do
        matcher = Onebox::Matcher.new("https://example.com", allowed_iframe_regexes: [])
        allow(matcher).to receive(:ordered_engines).and_return([TestEngine])
        expect(matcher.oneboxed).to be_nil
      end

      it "doesn't find an engine when only some subdomains are allowed" do
        matcher = Onebox::Matcher.new("https://example.com", allowed_iframe_regexes: Onebox::Engine.origins_to_regexes(["https://example.com"]))
        allow(matcher).to receive(:ordered_engines).and_return([TestEngine])
        expect(matcher.oneboxed).to be_nil
      end

      it "finds an engine when all required domains are allowed" do
        matcher = Onebox::Matcher.new("https://example.com", allowed_iframe_regexes: Onebox::Engine.origins_to_regexes(["https://example.com", "https://example2.com"]))
        allow(matcher).to receive(:ordered_engines).and_return([TestEngine])
        expect(matcher.oneboxed).not_to be_nil
      end
    end

  end
end

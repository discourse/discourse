# frozen_string_literal: true

require "rails_helper"

describe Onebox::Engine::HackernewsOnebox do
  context "When oneboxing a comment" do
    let(:link) { "https://news.ycombinator.com/item?id=30181167" }
    let(:api_link) { "https://hacker-news.firebaseio.com/v0/item/30181167.json" }
    let(:html) { described_class.new(link).to_html }

    before do
      stub_request(:get, api_link).to_return(status: 200, body: onebox_response("hackernews_comment"))
    end

    it "has the comments first words" do
      expect(html).to include("Completely, forums are about basic human expression in paragraph form.")
    end

    it "has author username" do
      expect(html).to include("codinghorror")
    end

    it "has the permalink to the comic" do
      expect(html).to include(link)
    end

    it "has the item date" do
      expect(html).to include("2013")
    end
  end

  context "When oneboxing a story" do
    let(:link) { "https://news.ycombinator.com/item?id=5172905" }
    let(:api_link) { "https://hacker-news.firebaseio.com/v0/item/5172905.json" }
    let(:html) { described_class.new(link).to_html }

    before do
      stub_request(:get, api_link).to_return(status: 200, body: onebox_response("hackernews_story"))
    end

    it "has story title" do
      expect(html).to include("Civilized Discourse Construction Kit")
    end

    it "has author username" do
      expect(html).to include("sosuke")
    end

    it "has the permalink to the comic" do
      expect(html).to include(link)
    end

    it "has the item date" do
      expect(html).to include("2013")
    end
  end
end

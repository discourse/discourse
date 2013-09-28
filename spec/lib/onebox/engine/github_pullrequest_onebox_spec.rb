require "spec_helper"

describe Onebox::Engine::GithubGistOnebox do
  let(:link) { "https://github.com/discourse/discourse/pull/1253/" }
  before do
    fake(link, response("github_pullrequest"))
  end

  it_behaves_like "an engine"

  describe "#to_html" do
    let(:html) { described_class.new(link).to_html }

    it "has pull request author" do
      expect(html).to include("jamesaanderson")
    end

    it "has repo name" do
      expect(html).to include("discourse")
    end

    it "has commit author gravatar" do
      expect(html).to include("gravatar-user-420.png")
    end

    it "has commit description" do
      expect(html).to include("8168")
    end

    it "has commit time and date" do
      expect(html).to include("2013-07-26 02:05:00")
    end

    it "has number of commits" do
      expect(html).to include("1")
    end

    it "has number of files changed" do
      expect(html).to include("4")
    end

    it "has number of additions" do
      expect(html).to include("19")
    end

    it "has number of deletions" do
      expect(html).to include("1")
    end

    it "has URL" do
      expect(html).to include(link)
    end
  end
end

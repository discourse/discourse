require "spec_helper"

describe Onebox::Engine::GithubGistOnebox do
  let(:link) { "http://gist.github.com" }
  before do
    fake(link, response("github_gist"))
  end

  it_behaves_like "engines"

  describe "#to_html" do
    let(:html) { described_class.new(link).to_html }

    it "has raw file contents" do
      expect(html).to include("# Create a new blog post on GitHub")
    end

    it "has author" do
      expect(html).to include("anikalindtner")
    end

    it "has URL" do
      expect(html).to include(link)
    end
  end
end

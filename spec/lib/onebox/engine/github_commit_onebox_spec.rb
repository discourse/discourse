require "spec_helper"

describe Onebox::Engine::GithubCommitOnebox do
  let(:link) { "http://github.com" }
  before do
    fake(link, response("github_commit.response"))
  end

  it_behaves_like "engines"

  describe "#to_html" do
    let(:html) { described_class.new(link).to_html }

    it "returns repo title" do
      expect(html).to include("discourse")
    end

    it "returns user image aka gravatar" do
      expect(html).to include("gravatar-user-420.png")
    end

    it "returns URL" do
      expect(html).to include(link)
    end
  end
end

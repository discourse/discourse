require "spec_helper"

describe Onebox::Engine::GithubGistOnebox do
  let(:link) { "http://github.com" }
  before do
    fake(link, response("github_gist.response"))
  end

  it_behaves_like "engines"

  describe "#to_html" do
    let(:html) { described_class.new(link).to_html }

    it "has repo owner" do
      expect(html).to include("discourse")
    end

    it "has URL" do
      expect(html).to include(link)
    end
  end
end

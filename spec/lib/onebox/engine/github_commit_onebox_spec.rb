require "spec_helper"

describe Onebox::Engine::GithubCommitOnebox do
  let(:link) { "http://github.com" }
  let(:html) { described_class.new(link).to_html }

  before do
    fake(link, response("github_commit.response"))
  end

  it "returns repo title" do
    expect(html).to include("discourse")
  end

  it "returns user gravatar" do
    expect(html).to include("gravatar-user-420.png")
  end

  it "returns URL" do
    expect(html).to include(link)
  end
end

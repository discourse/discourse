require "spec_helper"

describe Onebox::Engine::GithubBlobOnebox do
  let(:link) { "https://github.com/discourse/discourse/blob/master/lib/oneboxer/github_blob_onebox.rb" }
  before do
    fake(link, response("githubblob"))
  end

  it_behaves_like "an engine"

  describe "#to_html" do
    let(:html) { described_class.new(link).to_html }

    it "has file name" do
      expect(html).to include("github_blob_onebox.rb")
    end

    it "has number of lines" do
      expect(html).to include("50")
    end

    it "has blob contents" do
      expect(html).to include("module Oneboxer")
    end

    it "has URL" do
      expect(html).to include(link)
    end
  end
end

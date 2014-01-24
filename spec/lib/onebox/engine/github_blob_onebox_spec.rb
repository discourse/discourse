require "spec_helper"

describe Onebox::Engine::GithubBlobOnebox do
  before(:all) do
    @link = "https://github.com/discourse/discourse/blob/master/lib/oneboxer/github_blob_onebox.rb"
    fake("https://raw.github.com/discourse/discourse/master/lib/oneboxer/github_blob_onebox.rb", response(described_class.onebox_name))
  end

  include_context "engines"
  it_behaves_like "an engine"

  describe "#to_html" do
    it "includes file name" do
      expect(html).to include("github_blob_onebox.rb")
    end

    it "includes blob contents" do
      expect(html).to include("module Oneboxer")
    end
  end
end

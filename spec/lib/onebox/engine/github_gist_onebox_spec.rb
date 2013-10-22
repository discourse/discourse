require "spec_helper"

describe Onebox::Engine::GithubGistOnebox do
  before(:all) do
    @link = "https://gist.github.com/anikalindtner/153044e9bea3331cc103"
    @uri = "https://api.github.com/gists/153044e9bea3331cc103"
    fake(@uri, response(described_class.template_name))
  end

  include_context "engines"
  it_behaves_like "an engine"

  describe "#to_html" do
    it "includes raw file contents" do
      expect(html).to include("# Create a new blog post on GitHub")
    end

    it "includes author" do
      expect(html).to include("anikalindtner")
    end
  end
end

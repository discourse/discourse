require "spec_helper"

describe Onebox::Engine::GithubGistOnebox do
  before(:all) do
    @link = "https://gist.github.com/anikalindtner/153044e9bea3331cc103"
    @uri = "https://api.github.com/gists/153044e9bea3331cc103"
    fake(@uri, response(described_class.template_name))
  end
  before(:each) { Onebox.defaults.cache.clear }

  let(:onebox) { described_class.new(link) }
  let(:html) { onebox.to_html }
  let(:data) { onebox.send(:data) }
  let(:link) { @link }

  it_behaves_like "an engine"

  describe "#to_html" do
    it "has raw file contents" do
      expect(html).to include("# Create a new blog post on GitHub")
    end

    it "has author" do
      expect(html).to include("anikalindtner")
    end
  end
end

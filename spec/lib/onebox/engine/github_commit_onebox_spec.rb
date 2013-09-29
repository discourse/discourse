require "spec_helper"

describe Onebox::Engine::GithubCommitOnebox do
  before(:all) do
    @link = "https://github.com/discourse/discourse/commit/803d023e2307309f8b776ab3b8b7e38ba91c0919"
    fake(@link, response(described_class.template_name))
  end
  before(:each) { Onebox.defaults.cache.clear }

  let(:link) { @link }

  it_behaves_like "an engine"

  describe "#to_html" do
    let(:html) { described_class.new(link).to_html }

    it "has repo owner" do
      expect(html).to include("discourse")
    end

    it "has repo name" do
      expect(html).to include("discourse")
    end

    it "has commit sha" do
      expect(html).to include("803d023e2307309f8b776ab3b8b7e38ba91c0919")
    end

    it "has tag" do
      pending
      expect(html).to include("v0.9.6.3")
    end

    it "has branch" do
      expect(html).to include("master")
    end

    it "has commit author gravatar" do
      expect(html).to include("gravatar-user-420.png")
    end

    it "has commit message" do
      expect(html).to include("Fixed GitHub auth")
    end

    it "has commit description" do
      expect(html).to include("matically")
    end

    it "has commit author" do
      expect(html).to include("SamSaffron")
    end

    it "has commit time and date" do
      expect(html).to include("2013-08-01 19:03:53")
    end

    it "has number of files changed" do
      expect(html).to include("1 changed file")
    end

    it "has number of additions" do
      expect(html).to include("18 additions")
    end

    it "has number of deletions" do
      expect(html).to include("2 deletions")
    end

    it "has URL" do
      expect(html).to include(link)
    end
  end
end

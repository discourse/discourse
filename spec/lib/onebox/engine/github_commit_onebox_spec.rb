# frozen_string_literal: true

RSpec.describe Onebox::Engine::GithubCommitOnebox do
  describe "regular commit url" do
    before do
      stub_request(
        :get,
        "https://api.github.com/repos/discourse/discourse/commits/803d023e2307309f8b776ab3b8b7e38ba91c0919",
      ).to_return(status: 200, body: onebox_response("githubcommit"))
    end

    include_context "with engines" do
      let(:link) do
        "https://github.com/discourse/discourse/commit/803d023e2307309f8b776ab3b8b7e38ba91c0919"
      end
    end
    it_behaves_like "an engine"

    describe "#to_html" do
      it "includes repository name" do
        expect(html).to include("discourse/discourse")
      end

      it "includes commit sha" do
        expect(html).to include("803d023e2307309f8b776ab3b8b7e38ba91c0919")
      end

      it "includes commit author gravatar" do
        expect(html).to include("2F7d3010c11d08cf990b7614d2c2ca9098.png")
      end

      it "includes commit message" do
        expect(html).to include("Fixed GitHub auth")
      end

      it "includes commit author" do
        expect(html).to include("SamSaffron")
      end

      it "includes commit time and date" do
        expect(html).to include("02:16AM - 02 Aug 13 UTC")
      end

      it "includes number of files changed" do
        expect(html).to include("1 file")
      end

      it "includes number of additions" do
        expect(html).to include("18 additions")
      end

      it "includes number of deletions" do
        expect(html).to include("2 deletions")
      end
    end

    context "when github_onebox_access_token is configured" do
      before { SiteSetting.github_onebox_access_tokens = "discourse|github_pat_1234" }

      it "sends it as part of the request" do
        html
        expect(WebMock).to have_requested(
          :get,
          "https://api.github.com/repos/discourse/discourse/commits/803d023e2307309f8b776ab3b8b7e38ba91c0919",
        ).with(headers: { "Authorization" => "Bearer github_pat_1234" })
      end
    end
  end

  describe "PR with commit URL" do
    before do
      stub_request(
        :get,
        "https://api.github.com/repos/discourse/discourse/commits/803d023e2307309f8b776ab3b8b7e38ba91c0919",
      ).to_return(status: 200, body: onebox_response("githubcommit"))
    end

    include_context "with engines" do
      let(:link) do
        "https://github.com/discourse/discourse/pull/4662/commit/803d023e2307309f8b776ab3b8b7e38ba91c0919"
      end
    end
    # TODO: fix test to make sure it's not failing when matching object
    # it_behaves_like "an engine"

    describe "#to_html" do
      it "includes repository name" do
        expect(html).to include("discourse/discourse")
      end

      it "includes commit sha" do
        expect(html).to include("803d023e2307309f8b776ab3b8b7e38ba91c0919")
      end

      it "includes commit author gravatar" do
        expect(html).to include("2F7d3010c11d08cf990b7614d2c2ca9098.png")
      end

      it "includes commit message" do
        expect(html).to include("Fixed GitHub auth")
      end

      it "includes commit author" do
        expect(html).to include("SamSaffron")
      end

      it "includes commit time and date" do
        expect(html).to include("02:16AM - 02 Aug 13 UTC")
      end

      it "includes number of files changed" do
        expect(html).to include("1 file")
      end

      it "includes number of additions" do
        expect(html).to include("18 additions")
      end

      it "includes number of deletions" do
        expect(html).to include("2 deletions")
      end
    end

    context "when github_onebox_access_token is configured" do
      before { SiteSetting.github_onebox_access_tokens = "discourse|github_pat_1234" }

      it "sends it as part of the request" do
        html
        expect(WebMock).to have_requested(
          :get,
          "https://api.github.com/repos/discourse/discourse/commits/803d023e2307309f8b776ab3b8b7e38ba91c0919",
        ).with(headers: { "Authorization" => "Bearer github_pat_1234" })
      end
    end
  end

  describe ".===" do
    it "matches valid GitHub commit URL" do
      valid_url =
        URI("https://github.com/owner/repo/commit/9a9b9c9d9e9f9a9b9c9d9e9f9a9b9c9d9e9f9a9b")
      expect(described_class === valid_url).to eq(true)
    end

    it "does not match URL with subdomain" do
      subdomain_url =
        URI(
          "https://subdomain.github.com/owner/repo/commit/9a9b9c9d9e9f9g9h9i9j9k9l9m9n9o9p9q9r9s9t",
        )
      expect(described_class === subdomain_url).to eq(false)
    end

    it "does not match URL with additional domain" do
      malicious_url =
        URI(
          "https://github.com.malicious.com/owner/repo/commit/9a9b9c9d9e9f9g9h9i9j9k9l9m9n9o9p9q9r9s9t",
        )
      expect(described_class === malicious_url).to eq(false)
    end

    it "does not match URL with invalid path" do
      invalid_path_url =
        URI("https://github.com/owner/repo/invalid/9a9b9c9d9e9f9g9h9i9j9k9l9m9n9o9p9q9r9s9t")
      expect(described_class === invalid_path_url).to eq(false)
    end

    it "does not match URL with invalid commit hash" do
      invalid_hash_url = URI("https://github.com/owner/repo/commit/invalidhash")
      expect(described_class === invalid_hash_url).to eq(false)
    end
  end
end

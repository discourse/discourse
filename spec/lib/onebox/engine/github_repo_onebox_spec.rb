# frozen_string_literal: true

RSpec.describe Onebox::Engine::GithubRepoOnebox do
  let(:gh_link) { "https://github.com/discourse/discourse" }
  let(:api_uri) { "https://api.github.com/repos/discourse/discourse" }
  let(:response) { onebox_response(described_class.onebox_name) }

  before { stub_request(:get, api_uri).to_return(status: 200, body: response) }

  include_context "with engines" do
    let(:link) { gh_link }
  end
  it_behaves_like "an engine"

  describe "#to_html" do
    describe "repository metadata" do
      let(:repository) { MultiJson.load(onebox_response(described_class.onebox_name)) }
      let(:metadata) { Nokogiri::HTML5.fragment(html).at_css(".github-repo-metadata") }

      before do
        stub_request(:get, api_uri).to_return { { status: 200, body: MultiJson.dump(repository) } }
      end

      it "includes the primary language, stars and forks at the bottom" do
        expect(metadata.at_css(".github-repo-metadata__language").text).to eq("Ruby")
        expect(metadata.at_css(".github-repo-metadata__stars").text.strip).to eq("41.2k stars")
        expect(metadata.at_css(".github-repo-metadata__forks").text.strip).to eq("8.2k forks")
        expect(metadata.parent.element_children.last).to eq(metadata)
      end

      it "omits zero stars while retaining forks" do
        repository["stargazers_count"] = 0

        expect(metadata.at_css(".github-repo-metadata__stars")).to be_nil
        expect(metadata.at_css(".github-repo-metadata__forks")).to be_present
      end

      it "omits zero forks while retaining stars" do
        repository["forks_count"] = 0

        expect(metadata.at_css(".github-repo-metadata__forks")).to be_nil
        expect(metadata.at_css(".github-repo-metadata__stars")).to be_present
      end

      it "omits an unknown language while retaining counts" do
        repository["language"] = nil

        expect(metadata.at_css(".github-repo-metadata__language")).to be_nil
        expect(metadata.at_css(".github-repo-metadata__stars")).to be_present
        expect(metadata.at_css(".github-repo-metadata__forks")).to be_present
      end

      it "uses singular labels for one star and one fork" do
        repository["stargazers_count"] = 1
        repository["forks_count"] = 1

        expect(metadata.at_css(".github-repo-metadata__stars").text.strip).to eq("1 star")
        expect(metadata.at_css(".github-repo-metadata__forks").text.strip).to eq("1 fork")
      end

      it "keeps counts below a thousand exact" do
        repository["stargazers_count"] = 961
        repository["forks_count"] = 999

        expect(metadata.at_css(".github-repo-metadata__stars").text.strip).to eq("961 stars")
        expect(metadata.at_css(".github-repo-metadata__forks").text.strip).to eq("999 forks")
      end

      it "discloses the snapshot time using Discourse local-date markup" do
        freeze_time Time.utc(2026, 10, 6, 13, 45, 30)

        snapshot = metadata.at_css(".github-repo-metadata__snapshot")
        date = snapshot.at_css(".discourse-local-date")

        expect(snapshot.text).to eq("(Snapshot: 01:45PM - 06 Oct 26 UTC)")
        expect(date["data-date"]).to eq("2026-10-06")
        expect(date["data-time"]).to eq("13:45:30")
        expect(date["data-timezone"]).to eq("UTC")
        expect(date["data-format"]).to eq("lll")
        expect(metadata.element_children.last).to eq(snapshot)
      end

      it "keeps the original snapshot time when a cached onebox is reused" do
        freeze_time Time.utc(2026, 10, 6, 13, 45, 30)
        Oneboxer.invalidate(gh_link)
        Oneboxer.expects(:compute_external_onebox).once.returns(onebox: html, preview: html)
        original = Oneboxer.external_onebox(gh_link)

        freeze_time Time.utc(2026, 10, 6, 15, 0, 0)

        expect(Oneboxer.external_onebox(gh_link)).to eq(original)
        expect(original[:onebox]).to include('data-time="13:45:30"')
      ensure
        Oneboxer.invalidate(gh_link)
      end

      it "abbreviates thousands with one decimal place" do
        repository["stargazers_count"] = 195_900
        repository["forks_count"] = 17_000

        expect(metadata.at_css(".github-repo-metadata__stars").text.strip).to eq("195.9k stars")
        expect(metadata.at_css(".github-repo-metadata__forks").text.strip).to eq("17.0k forks")
      end

      it "abbreviates counts starting at a thousand" do
        repository["stargazers_count"] = 1000

        expect(metadata.at_css(".github-repo-metadata__stars").text.strip).to eq("1.0k stars")
      end

      it "abbreviates millions with one decimal place" do
        repository["stargazers_count"] = 1_234_567
        repository["forks_count"] = 1_000_000

        expect(metadata.at_css(".github-repo-metadata__stars").text.strip).to eq("1.2M stars")
        expect(metadata.at_css(".github-repo-metadata__forks").text.strip).to eq("1.0M forks")
      end

      it "promotes counts that round up to a million" do
        repository["stargazers_count"] = 999_950
        repository["forks_count"] = 999_949

        expect(metadata.at_css(".github-repo-metadata__stars").text.strip).to eq("1.0M stars")
        expect(metadata.at_css(".github-repo-metadata__forks").text.strip).to eq("999.9k forks")
      end

      it "omits a blank language while retaining counts" do
        repository["language"] = ""

        expect(metadata.at_css(".github-repo-metadata__language")).to be_nil
        expect(metadata.at_css(".github-repo-metadata__stars")).to be_present
      end

      it "omits the footer when there is no metadata" do
        repository["language"] = nil
        repository["stargazers_count"] = 0
        repository["forks_count"] = 0

        expect(metadata).to be_nil
      end

      it "handles missing metadata fields" do
        repository.except!("language", "stargazers_count", "forks_count")

        expect(metadata).to be_nil
      end

      it "escapes the language" do
        repository["language"] = "<script>alert(1)</script>"

        expect(metadata.at_css(".github-repo-metadata__language").text).to eq(
          repository["language"],
        )
        expect(metadata.css("script")).to be_empty
      end

      it "preserves the metadata and decorative icons through onebox sanitization" do
        preview = Onebox.preview(gh_link, sanitize_config: Onebox::SanitizeConfig::DISCOURSE_ONEBOX)
        sanitized_metadata = Nokogiri::HTML5.fragment(preview.to_s).at_css(".github-repo-metadata")

        expect(sanitized_metadata.at_css(".github-repo-metadata__language").text).to eq("Ruby")
        expect(sanitized_metadata.at_css(".github-repo-metadata__stars").text.strip).to eq(
          "41.2k stars",
        )
        expect(sanitized_metadata.at_css(".github-repo-metadata__forks").text.strip).to eq(
          "8.2k forks",
        )
        expect(
          sanitized_metadata.css(".github-repo-metadata__icon[aria-hidden='true'] path").size,
        ).to eq(2)
        snapshot_date =
          sanitized_metadata.at_css(".github-repo-metadata__snapshot .discourse-local-date")
        expect(snapshot_date["data-date"]).to be_present
        expect(snapshot_date["data-time"]).to be_present
        expect(snapshot_date["data-format"]).to eq("lll")
        expect(snapshot_date["data-timezone"]).to eq("UTC")
        expect(WebMock).to have_requested(:get, api_uri).once
      end

      it "uses translated count labels and compact numbers in the active locale" do
        TranslationOverride.upsert!(:de, "onebox.github.stars.other", "%{number} Sterne")
        TranslationOverride.upsert!(:de, "onebox.github.forks.other", "%{number} Forks")
        TranslationOverride.upsert!(:de, "onebox.github.snapshot", "Momentaufnahme")

        I18n.with_locale(:de) do
          expect(metadata.at_css(".github-repo-metadata__stars").text.strip).to eq("41,2 T. Sterne")
          expect(metadata.at_css(".github-repo-metadata__forks").text.strip).to eq("8,2 T. Forks")
          expect(metadata.at_css(".github-repo-metadata__snapshot").text).to start_with(
            "(Momentaufnahme:",
          )
        end
      end
    end

    it "includes the description of the repo" do
      expect(html).to include("A platform for community discussion. Free, open, simple.")
    end

    it "includes the name of the repo and truncated description for the title" do
      expect(html).to include(
        "GitHub - discourse/discourse: A platform for community discussion. Free, open,...",
      )
    end

    it "includes a thumbnail url" do
      SecureRandom.stubs(:hex).returns("1234")
      expect(html).to include("https://opengraph.githubassets.com/1234/discourse/discourse")
    end

    it "sets the data-github-private-repo attr to false" do
      expect(html).to include("data-github-private-repo=\"false\"")
    end

    context "when the PR is in a private repo" do
      let(:response) do
        resp = MultiJson.load(onebox_response(described_class.onebox_name))
        resp["private"] = true
        MultiJson.dump(resp)
      end

      it "sets the data-github-private-repo attr to true" do
        expect(html).to include("data-github-private-repo=\"true\"")
      end
    end

    context "when the repo has no description" do
      let(:response) do
        resp = MultiJson.load(onebox_response(described_class.onebox_name))
        resp["description"] = ""
        MultiJson.dump(resp)
      end

      it "includes a message about contributing to the repo" do
        expect(html).to include(I18n.t("onebox.github.no_description", repo: "discourse/discourse"))
      end
    end
  end

  context "when github_onebox_access_token is configured" do
    before { SiteSetting.github_onebox_access_tokens = "discourse|github_pat_1234" }

    it "sends it as part of the request" do
      html
      expect(WebMock).to have_requested(:get, api_uri).with(
        headers: {
          "Authorization" => "Bearer github_pat_1234",
        },
      )
    end
  end

  describe "#inline_data" do
    it "returns nil when no access token is configured" do
      expect(described_class.new(gh_link).inline_data).to be_nil
    end

    it "returns the repo title from the API when an access token is configured" do
      SiteSetting.github_onebox_access_tokens = "discourse|github_pat_1234"
      expect(described_class.new(gh_link).inline_data).to eq(
        title: "GitHub - discourse/discourse - A platform for community discussion. Free, open,...",
      )
    end
  end

  describe ".===" do
    it "matches valid GitHub repository URL" do
      valid_url = URI("https://github.com/username/repository/")
      expect(described_class === valid_url).to eq(true)
    end

    it "matches valid GitHub repository URL without trailing slash" do
      valid_url_without_slash = URI("https://github.com/username/repository")
      expect(described_class === valid_url_without_slash).to eq(true)
    end

    it "matches valid GitHub repository URL with www" do
      valid_url_with_www = URI("https://www.github.com/username/repository/")
      expect(described_class === valid_url_with_www).to eq(true)
    end

    it "does not match Gist URL" do
      gist_url = URI("https://gist.github.com/username/123456")
      expect(described_class === gist_url).to eq(false)
    end

    it "does not match URL with valid domain as part of another domain" do
      malicious_url = URI("https://github.com.malicious.com/username/repository/")
      expect(described_class === malicious_url).to eq(false)
    end

    it "does not match invalid path" do
      invalid_path_url = URI("https://github.com/username/repository/invalid")
      expect(described_class === invalid_path_url).to eq(false)
    end
  end
end

# frozen_string_literal: true

RSpec.describe Onebox::Engine::GithubPullRequestOnebox do
  let(:gh_link) { "https://github.com/discourse/discourse/pull/1253/" }
  let(:api_uri) { "https://api.github.com/repos/discourse/discourse/pulls/1253" }
  let(:response) { onebox_response(described_class.onebox_name) }

  before do
    SiteSetting.stubs(:github_pr_status_enabled).returns(false)
    stub_request(:get, api_uri).to_return(status: 200, body: response)
  end

  include_context "with engines" do
    let(:link) { gh_link }
  end
  it_behaves_like "an engine"

  describe "#to_html" do
    it "shows a neutral pull request header when PR status is disabled" do
      preview = Nokogiri::HTML5.fragment(html)
      header = preview.at_css("aside > header")

      expect(preview.css("aside > header").size).to eq(1)
      expect(header.at_css(".github-onebox__label").text.strip).to eq("Pull request")
      expect(header.at_css(".github-onebox__label svg")).to be_present
      expect(header.at_css("a").text.strip).to eq("discourse/discourse")
      expect(header.at_css("a")["href"]).to eq(gh_link)
      expect(preview.at_css("aside")["class"].split.grep(/\A--github-/)).to eq([])
    end

    it "links the title and parenthesized pull request number together" do
      title_link = Nokogiri::HTML5.fragment(html).at_css("h4 a")

      expect(title_link.text).to eq("Add audio onebox (#1253)")
      expect(title_link["href"]).to eq(gh_link)
    end

    it "includes pull request author" do
      expect(html).to include("jamesaanderson")
    end

    it "includes branch names" do
      expect(html).to include("<code>main</code> ← <code>jamesaanderson:add-audio-onebox</code>")
    end

    it "includes commit author gravatar" do
      expect(html).to include("b3e9977094ce189bbb493cf7f9adea21")
    end

    it "includes commit time and date" do
      expect(html).to include("02:05AM - 26 Jul 13")
    end

    it "shows the additions, deletions and change summary" do
      lines = Nokogiri::HTML5.fragment(html).at_css(".lines")

      expect(lines.at_css(".added").text).to eq("+19")
      expect(lines.at_css(".removed").text).to eq("-5")
      expect(lines["title"]).to eq("1 commits changed 4 files with 19 additions and 5 deletions")
    end

    it "includes the body without comments" do
      expect(html).to include("http://meta.discourse.org/t/audio-html5-tag/8168")
      expect(html).not_to include("test comment")
    end

    it "sets the data-github-private-repo attr to false" do
      expect(html).to include("data-github-private-repo=\"false\"")
    end

    context "when the PR is in a private repo" do
      let(:response) do
        resp = MultiJson.load(onebox_response(described_class.onebox_name))
        resp["base"]["repo"]["private"] = true
        MultiJson.dump(resp)
      end

      it "sets the data-github-private-repo attr to true" do
        expect(html).to include("data-github-private-repo=\"true\"")
      end
    end

    it "shows the review comment header and body for a discussion link" do
      review_link = "#{gh_link}#discussion_r123"
      stub_request(
        :get,
        "https://api.github.com/repos/discourse/discourse/pulls/comments/123",
      ).to_return(body: MultiJson.dump("body" => "Please rename this method."))

      preview = Nokogiri::HTML5.fragment(described_class.new(review_link).to_html)

      expect(preview.at_css(".github-onebox__label").text.strip).to eq("Review comment")
      expect(preview.at_css(".github-body-container").text.strip).to eq(
        "Please rename this method.",
      )
    end

    context "when PR status is enabled" do
      let(:pr_response) do
        MultiJson.load(response).merge("state" => "open", "merged" => false, "draft" => false)
      end

      before do
        SiteSetting.stubs(:github_pr_status_enabled).returns(true)
        stub_request(:get, api_uri).to_return { { body: MultiJson.dump(pr_response) } }
        stub_request(:get, "#{api_uri}/reviews").to_return(body: "[]")
      end

      it "shows Open with the creation date for an unreviewed PR" do
        preview = Nokogiri::HTML5.fragment(html)

        expect(preview.at_css(".github-onebox__label").text.strip).to eq("Open")
        expect(preview.at_css("aside")["class"].split.grep(/\A--github-/)).to eq(["--github-open"])
        expect(preview.at_css(".discourse-local-date")["data-date"]).to eq("2013-07-26")
      end

      it "shows Draft with the creation date for a draft PR" do
        pr_response["draft"] = true

        preview = Nokogiri::HTML5.fragment(html)

        expect(preview.at_css(".github-onebox__label").text.strip).to eq("Draft")
        expect(preview.at_css("aside")["class"].split.grep(/\A--github-/)).to eq(["--github-draft"])
        expect(preview.at_css(".discourse-local-date")["data-date"]).to eq("2013-07-26")
      end

      it "shows Merged with the merge date for a merged PR" do
        pr_response.merge!(
          "merged" => true,
          "state" => "closed",
          "merged_at" => "2024-02-15T10:30:00Z",
        )

        preview = Nokogiri::HTML5.fragment(html)

        expect(preview.at_css(".github-onebox__label").text.strip).to eq("Merged")
        expect(preview.at_css("aside")["class"].split.grep(/\A--github-/)).to eq(
          ["--github-merged"],
        )
        expect(preview.at_css(".discourse-local-date")["data-date"]).to eq("2024-02-15")
      end

      it "shows Closed with the closing date for an unmerged closed PR" do
        pr_response.merge!("state" => "closed", "closed_at" => "2024-03-20T14:45:00Z")

        preview = Nokogiri::HTML5.fragment(html)

        expect(preview.at_css(".github-onebox__label").text.strip).to eq("Closed")
        expect(preview.at_css("aside")["class"].split.grep(/\A--github-/)).to eq(
          ["--github-closed"],
        )
        expect(preview.at_css(".discourse-local-date")["data-date"]).to eq("2024-03-20")
      end

      it "shows Approved with the approval date" do
        reviews = [
          {
            "user" => {
              "id" => 1,
            },
            "state" => "APPROVED",
            "submitted_at" => "2024-04-10T09:15:00Z",
          },
        ]
        stub_request(:get, "#{api_uri}/reviews").to_return(body: MultiJson.dump(reviews))

        preview = Nokogiri::HTML5.fragment(html)

        expect(preview.at_css(".github-onebox__label").text.strip).to eq("Approved")
        expect(preview.at_css("aside")["class"].split.grep(/\A--github-/)).to eq(
          ["--github-approved"],
        )
        expect(preview.at_css(".discourse-local-date")["data-date"]).to eq("2024-04-10")
      end

      it "shows Changes requested with the review date" do
        reviews = [
          {
            "user" => {
              "id" => 1,
            },
            "state" => "CHANGES_REQUESTED",
            "submitted_at" => "2024-05-05T16:20:00Z",
          },
        ]
        stub_request(:get, "#{api_uri}/reviews").to_return(body: MultiJson.dump(reviews))

        preview = Nokogiri::HTML5.fragment(html)

        expect(preview.at_css(".github-onebox__label").text.strip).to eq("Changes requested")
        expect(preview.at_css("aside")["class"].split.grep(/\A--github-/)).to eq(
          ["--github-changes_requested"],
        )
        expect(preview.at_css(".discourse-local-date")["data-date"]).to eq("2024-05-05")
      end

      it "prioritizes a change request over another reviewer's approval" do
        reviews = [
          {
            "user" => {
              "id" => 1,
            },
            "state" => "CHANGES_REQUESTED",
            "submitted_at" => "2024-06-01T12:00:00Z",
          },
          {
            "user" => {
              "id" => 2,
            },
            "state" => "APPROVED",
            "submitted_at" => "2024-06-02T12:00:00Z",
          },
        ]
        stub_request(:get, "#{api_uri}/reviews").to_return(body: MultiJson.dump(reviews))

        preview = Nokogiri::HTML5.fragment(html)

        expect(preview.at_css(".github-onebox__label").text.strip).to eq("Changes requested")
        expect(preview.at_css(".discourse-local-date")["data-date"]).to eq("2024-06-01")
      end

      it "uses each reviewer's latest review even when API results arrive out of order" do
        reviews = [
          {
            "user" => {
              "id" => 1,
            },
            "state" => "APPROVED",
            "submitted_at" => "2024-01-02T00:00:00Z",
          },
          {
            "user" => {
              "id" => 1,
            },
            "state" => "CHANGES_REQUESTED",
            "submitted_at" => "2024-01-01T00:00:00Z",
          },
        ]
        stub_request(:get, "#{api_uri}/reviews").to_return(body: MultiJson.dump(reviews))

        preview = Nokogiri::HTML5.fragment(html)

        expect(preview.at_css(".github-onebox__label").text.strip).to eq("Approved")
        expect(preview.at_css(".discourse-local-date")["data-date"]).to eq("2024-01-02")
      end

      it "keeps a neutral header and creation date when the reviews API fails" do
        stub_request(:get, "#{api_uri}/reviews").to_return(status: 500, body: "error")

        preview = Nokogiri::HTML5.fragment(html)

        expect(preview.at_css(".github-onebox__label").text.strip).to eq("Pull request")
        expect(preview.at_css("aside")["class"].split.grep(/\A--github-/)).to eq([])
        expect(preview.at_css(".discourse-local-date")["data-date"]).to eq("2013-07-26")
      end
    end
  end

  context "with commit links" do
    let(:gh_link) do
      "https://github.com/discourse/discourse/pull/1253/commits/d7d3be1130c665cc7fab9f05dbf32335229137a6"
    end
    let(:pr_commit_url) do
      "https://api.github.com/repos/discourse/discourse/commits/d7d3be1130c665cc7fab9f05dbf32335229137a6"
    end

    before do
      stub_request(:get, pr_commit_url).to_return(
        status: 200,
        body: onebox_response(described_class.onebox_name + "_commit"),
      )
    end

    it "includes commit name" do
      doc = Nokogiri.HTML5(html)
      expect(doc.at_css(".github-onebox__label").text.strip).to eq("Commit")
      expect(doc.css("h4").text.strip).to eq("Add audio onebox")
      expect(doc.css(".github-body-container").text).to include(
        "http://meta.discourse.org/t/audio-html5-tag/8168",
      )
    end

    context "when github_onebox_access_token is configured" do
      before { SiteSetting.github_onebox_access_tokens = "discourse|github_pat_1234" }

      it "sends it as part of the request" do
        html
        expect(WebMock).to have_requested(:get, pr_commit_url).with(
          headers: {
            "Authorization" => "Bearer github_pat_1234",
          },
        )
      end
    end
  end

  context "with comment links" do
    let(:gh_link) { "https://github.com/discourse/discourse/pull/1253/#issuecomment-21597425" }
    let(:comment_api_url) do
      "https://api.github.com/repos/discourse/discourse/issues/comments/21597425"
    end

    before do
      stub_request(:get, comment_api_url).to_return(
        status: 200,
        body: onebox_response(described_class.onebox_name + "_comment"),
      )
    end

    it "keeps the comment header and body when the parent PR is merged" do
      SiteSetting.stubs(:github_pr_status_enabled).returns(true)

      preview = Nokogiri::HTML5.fragment(html)

      expect(preview.at_css(".github-onebox__label").text.strip).to eq("Comment")
      expect(preview.at_css("aside")["class"].split.grep(/\A--github-/)).to eq([])
      expect(preview.at_css(".github-body-container").text).to include("You've signed the CLA")
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
    it "returns nil when no token is configured and github_pr_status_enabled is false" do
      SiteSetting.stubs(:github_pr_status_enabled).returns(false)
      expect(onebox.inline_data).to be_nil
    end

    it "returns the title when a token is configured and PR status is disabled" do
      SiteSetting.stubs(:github_pr_status_enabled).returns(false)
      SiteSetting.github_onebox_access_tokens = "discourse|github_pat_1234"

      expect(onebox.inline_data).to eq(
        title: "Add audio onebox - Pull Request #1253 - discourse/discourse - GitHub",
      )
    end

    it "returns the commit title when the URL links to a specific commit in the PR" do
      SiteSetting.github_onebox_access_tokens = "discourse|github_pat_1234"
      sha = "803d023e2307309f8b776ab3b8b7e38ba91c0919"
      commit_onebox =
        Onebox::Engine::GithubPullRequestOnebox.new(
          "https://github.com/discourse/discourse/pull/1253/commits/#{sha}",
        )
      stub_request(
        :get,
        "https://api.github.com/repos/discourse/discourse/commits/#{sha}",
      ).to_return(
        status: 200,
        body: MultiJson.dump("sha" => sha, "commit" => { "message" => "Add audio onebox" }),
      )

      expect(commit_onebox.inline_data).to eq(
        title: "Add audio onebox - discourse/discourse@803d023 - GitHub",
      )
    end

    context "when github_pr_status_enabled is true" do
      before { SiteSetting.stubs(:github_pr_status_enabled).returns(true) }

      it "returns a title with repo and PR number plus a status css class" do
        pr_response = MultiJson.load(response).merge("state" => "open", "merged" => false)
        stub_request(:get, api_uri).to_return(body: MultiJson.dump(pr_response))
        stub_request(:get, "#{api_uri}/reviews").to_return(status: 200, body: "[]")

        expect(onebox.inline_data).to eq(
          title: "Add audio onebox - Pull Request #1253 - discourse/discourse - GitHub",
          css_class: "--gh-status-open",
        )
      end

      it "returns the title without a status css class when the status fetch fails" do
        pr_response = MultiJson.load(response).merge("state" => "open", "merged" => false)
        stub_request(:get, api_uri).to_return(body: MultiJson.dump(pr_response))
        stub_request(:get, "#{api_uri}/reviews").to_return(status: 500, body: "error")

        expect(onebox.inline_data).to eq(
          title: "Add audio onebox - Pull Request #1253 - discourse/discourse - GitHub",
        )
      end
    end
  end

  describe ".===" do
    it "matches valid GitHub Pull Request URL" do
      valid_url = URI("https://github.com/username/repository/pull/123")
      expect(described_class === valid_url).to eq(true)
    end

    it "matches valid GitHub Pull Request URL with www" do
      valid_url_with_www = URI("https://www.github.com/username/repository/pull/123")
      expect(described_class === valid_url_with_www).to eq(true)
    end

    it "does not match URL with valid domain as part of another domain" do
      malicious_url = URI("https://github.com.malicious.com/username/repository/pull/123")
      expect(described_class === malicious_url).to eq(false)
    end

    it "does not match invalid path" do
      invalid_path_url = URI("https://github.com/username/repository/invalid/1234567890abcdef")
      expect(described_class === invalid_path_url).to eq(false)
    end
  end
end

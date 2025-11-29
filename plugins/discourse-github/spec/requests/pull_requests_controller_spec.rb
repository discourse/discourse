# frozen_string_literal: true

describe DiscourseGithub::PullRequestsController do
  let(:owner) { "discourse" }
  let(:repo) { "discourse" }
  let(:pr_number) { 123 }

  before { enable_current_plugin }

  describe "#status" do
    it "returns the PR status when successful" do
      GithubPrStatus.stubs(:fetch).with(owner, repo, pr_number.to_s).returns("open")

      get "/discourse-github/#{owner}/#{repo}/pulls/#{pr_number}/status.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["state"]).to eq("open")
    end

    it "returns bad_gateway when GithubPrStatus returns nil" do
      GithubPrStatus.stubs(:fetch).with(owner, repo, pr_number.to_s).returns(nil)

      get "/discourse-github/#{owner}/#{repo}/pulls/#{pr_number}/status.json"

      expect(response.status).to eq(502)
      expect(response.parsed_body["error"]).to eq(
        I18n.t("discourse_github.errors.failed_to_fetch_pr_status"),
      )
    end

    %w[merged closed draft approved open].each do |state|
      it "returns '#{state}' status correctly" do
        GithubPrStatus.stubs(:fetch).with(owner, repo, pr_number.to_s).returns(state)

        get "/discourse-github/#{owner}/#{repo}/pulls/#{pr_number}/status.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["state"]).to eq(state)
      end
    end

    it "handles hyphens in owner and repo names" do
      special_owner = "my-org"
      special_repo = "my-repo"
      GithubPrStatus.stubs(:fetch).with(special_owner, special_repo, pr_number.to_s).returns("open")

      get "/discourse-github/#{special_owner}/#{special_repo}/pulls/#{pr_number}/status.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["state"]).to eq("open")
    end
  end
end

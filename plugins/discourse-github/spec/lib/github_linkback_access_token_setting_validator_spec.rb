# frozen_string_literal: true

describe GithubLinkbackAccessTokenSettingValidator do
  subject(:validator) { described_class.new }

  let(:value) { SecureRandom.hex(10) }

  before { enable_current_plugin }

  describe "#valid_value?" do
    context "when the token cannot access a repo (401)" do
      before do
        setup_repos
        stub_request(:get, "https://api.github.com/repos/discourse/discourse/branches").to_return(
          status: 401,
        )
      end

      it "should fail" do
        expect(validator.valid_value?(value)).to eq(false)
      end
    end

    context "when a repo is missing or private (404)" do
      before do
        setup_repos
        stub_request(:get, "https://api.github.com/repos/discourse/discourse/branches").to_return(
          status: 404,
        )
      end

      it "should fail" do
        expect(validator.valid_value?(value)).to eq(false)
      end
    end

    context "when the token is accepted" do
      it "should pass, without repos defined" do
        expect(validator.valid_value?(value)).to eq(true)
      end

      context "when there are repos defined" do
        before do
          setup_repos
          stub_request(:get, "https://api.github.com/repos/discourse/discourse/branches").to_return(
            status: 200,
            body: "[]",
          )
        end

        it "should pass if all the repos are accessible" do
          expect(validator.valid_value?(value)).to eq(true)
        end
      end
    end
  end

  describe "#error_message" do
    it "returns the generic message when no specific repo failed" do
      expect(validator.error_message).to eq(
        I18n.t("site_settings.errors.invalid_github_linkback_access_token"),
      )
    end

    it "names the failing repo when access is unauthorized (401)" do
      setup_repos("discourse/discourse|acme/private-repo|foo/bar")
      stub_branches("discourse/discourse", status: 200)
      stub_branches("acme/private-repo", status: 401)

      expect(validator.valid_value?(value)).to eq(false)
      expect(validator.error_message).to eq(
        I18n.t(
          "site_settings.errors.invalid_github_linkback_access_token_for_repo",
          repo: "acme/private-repo",
        ),
      )
    end

    it "names the failing repo when it is missing or private (404)" do
      setup_repos("discourse/discourse|acme/typo-repo")
      stub_branches("discourse/discourse", status: 200)
      stub_branches("acme/typo-repo", status: 404)

      expect(validator.valid_value?(value)).to eq(false)
      expect(validator.error_message).to eq(
        I18n.t(
          "site_settings.errors.invalid_github_linkback_access_token_for_repo",
          repo: "acme/typo-repo",
        ),
      )
    end
  end

  def setup_repos(repos = "discourse/discourse")
    SiteSetting.github_badges_repos = repos
    DiscourseGithubPlugin::GithubRepo.repos
  end

  def stub_branches(repo, status:)
    stub_request(:get, "https://api.github.com/repos/#{repo}/branches").to_return(status:)
  end
end

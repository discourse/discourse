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

  def setup_repos
    SiteSetting.github_badges_repos = "discourse/discourse"
    DiscourseGithubPlugin::GithubRepo.repos
  end
end

# frozen_string_literal: true

RSpec.describe ProblemCheck::GithubOneboxBackoff do
  subject(:check) { described_class.new }

  describe "#call" do
    context "when no GitHub backoff is active" do
      it { expect(check).to be_chill_about_it }
    end

    context "when the unauthenticated onebox client is backing off" do
      before { GithubRateLimit.note_rate_limit(remaining: "0", reset_at: 10.minutes.from_now.to_i) }

      it { expect(check).to have_a_problem.with_priority("low") }
    end

    context "when a configured onebox token is backing off" do
      before do
        SiteSetting.github_onebox_access_tokens = "default|onebox_token"
        GithubRateLimit.note_rate_limit(
          token: "onebox_token",
          remaining: "0",
          reset_at: 10.minutes.from_now.to_i,
        )
      end

      it { expect(check).to have_a_problem.with_priority("low") }
    end

    context "when only an unrelated GitHub token is backing off" do
      before do
        SiteSetting.github_onebox_access_tokens = "default|onebox_token"
        GithubRateLimit.note_rate_limit(
          token: "ai_bot_token",
          remaining: "0",
          reset_at: 10.minutes.from_now.to_i,
        )
      end

      it { expect(check).to be_chill_about_it }
    end
  end
end

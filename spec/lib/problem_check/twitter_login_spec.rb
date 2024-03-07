# frozen_string_literal: true

RSpec.describe ProblemCheck::TwitterLogin do
  let(:problem_check) { described_class.new }
  let(:tracker) { Fabricate(:problem_check_tracker, identifier: "twitter_login", blips: blips) }

  let!(:authenticator) { Auth::TwitterAuthenticator.new }
  let(:blips) { 0 }

  before do
    SiteSetting.enable_twitter_logins = true

    Auth::TwitterAuthenticator.stubs(:new).returns(authenticator)
  end

  describe "#call" do
    context "when Twitter authentication isn't enabled" do
      before { SiteSetting.enable_twitter_logins = false }

      it { expect(problem_check.call(tracker)).to be_empty }
    end

    context "when Twitter authentication appears to work" do
      before { authenticator.stubs(:healthy?).returns(true) }

      it { expect(problem_check.call(tracker)).to be_empty }
    end

    context "when Twitter authentication appears not to work" do
      before do
        authenticator.stubs(:healthy?).returns(false)
        Discourse.stubs(:base_path).returns("foo.bar")
      end

      it do
        expect(problem_check.call(tracker)).to contain_exactly(
          have_attributes(
            identifier: :twitter_login,
            priority: "high",
            message:
              'Twitter login appears to not be working at the moment. Check the credentials in <a href="foo.bar/admin/site_settings/category/login?filter=twitter">the Site Settings</a>.',
          ),
        )
      end
    end

    context "when Twitter authentication seems to be permanently broken" do
      before do
        authenticator.stubs(:healthy?).returns(false)
        Discourse.stubs(:base_path).returns("foo.bar")
      end

      let(:blips) { 3 }

      context "when configured to disable broken social login methods" do
        before { SiteSetting.disable_failing_social_logins = true }

        it do
          expect { problem_check.call(tracker) }.to change {
            SiteSetting.enable_twitter_logins
          }.from(true).to(false)
        end
      end

      context "when configured to not disable  broken social login methods" do
        before { SiteSetting.disable_failing_social_logins = false }

        it do
          expect { problem_check.call(tracker) }.not_to change { SiteSetting.enable_twitter_logins }
        end
      end
    end
  end
end

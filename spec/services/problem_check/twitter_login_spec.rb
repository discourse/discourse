# frozen_string_literal: true

RSpec.describe ProblemCheck::TwitterLogin do
  let(:check) { described_class.new }

  let(:authenticator) { mock("Auth::TwitterAuthenticator") }

  before { Auth::TwitterAuthenticator.stubs(:new).returns(authenticator) }

  describe "#call" do
    context "when Twitter authentication isn't enabled" do
      before { authenticator.stubs(:enabled?).returns(false) }

      it { expect(check).to be_chill_about_it }
    end

    context "when Twitter authentication appears to work" do
      before do
        authenticator.stubs(:enabled?).returns(true)
        authenticator.stubs(:healthy?).returns(true)
      end

      it { expect(check).to be_chill_about_it }
    end

    context "when Twitter authentication appears not to work" do
      before do
        authenticator.stubs(:enabled?).returns(true)
        authenticator.stubs(:healthy?).returns(false)
        Discourse.stubs(:base_path).returns("foo.bar")
      end

      it do
        expect(check).to have_a_problem.with_priority("high").with_message(
          'Twitter login appears to not be working at the moment. Check the credentials in <a href="foo.bar/admin/site_settings/category/login?filter=twitter">the Site Settings</a>.',
        )
      end
    end
  end
end

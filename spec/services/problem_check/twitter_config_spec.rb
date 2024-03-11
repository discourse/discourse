# frozen_string_literal: true

RSpec.describe ProblemCheck::TwitterConfig do
  subject(:check) { described_class.new }

  describe ".call" do
    before { SiteSetting.stubs(enable_twitter_logins: enabled) }

    context "when Twitter authentication is disabled" do
      let(:enabled) { false }

      it { expect(check.call).to be_empty }
    end

    context "when Twitter authentication is enabled and configured" do
      let(:enabled) { true }

      before do
        SiteSetting.stubs(twitter_consumer_key: "foo")
        SiteSetting.stubs(twitter_consumer_secret: "bar")
      end

      it { expect(check.call).to be_empty }
    end

    context "when Twitter authentication is enabled but missing client ID" do
      let(:enabled) { true }

      before do
        SiteSetting.stubs(twitter_consumer_key: nil)
        SiteSetting.stubs(twitter_consumer_secret: "bar")
      end

      it { expect(check.call).to include(be_a(ProblemCheck::Problem)) }
    end

    context "when Twitter authentication is enabled but missing client secret" do
      let(:enabled) { true }

      before do
        SiteSetting.stubs(twitter_consumer_key: "foo")
        SiteSetting.stubs(twitter_consumer_secret: nil)
      end

      it { expect(check.call).to include(be_a(ProblemCheck::Problem)) }
    end
  end
end

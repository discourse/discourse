# frozen_string_literal: true

RSpec.describe ProblemCheck::TwitterConfig do
  subject(:check) { described_class.new }

  describe ".call" do
    before { SiteSetting.stubs(enable_twitter_logins: enabled) }

    context "when Twitter authentication is disabled" do
      let(:enabled) { false }

      it { expect(check).to be_chill_about_it }
    end

    context "when Twitter authentication is enabled and configured" do
      let(:enabled) { true }

      before do
        SiteSetting.stubs(twitter_consumer_key: "foo")
        SiteSetting.stubs(twitter_consumer_secret: "bar")
      end

      it { expect(check).to be_chill_about_it }
    end

    context "when Twitter authentication is enabled but missing client ID" do
      let(:enabled) { true }

      before do
        SiteSetting.stubs(twitter_consumer_key: nil)
        SiteSetting.stubs(twitter_consumer_secret: "bar")
      end

      it do
        expect(check).to have_a_problem.with_priority("low").with_message(
          '{{setting:enable_twitter_logins}} is on, but {{setting:twitter_consumer_key}} must still be set. <a href="https://meta.discourse.org/t/configuring-twitter-login-for-discourse/13395" target="_blank">See this guide to learn more</a>.',
        )
      end
    end

    context "when Twitter authentication is enabled but missing client secret" do
      let(:enabled) { true }

      before do
        SiteSetting.stubs(twitter_consumer_key: "foo")
        SiteSetting.stubs(twitter_consumer_secret: nil)
      end

      it do
        expect(check).to have_a_problem.with_priority("low").with_message(
          '{{setting:enable_twitter_logins}} is on, but {{setting:twitter_consumer_secret}} must still be set. <a href="https://meta.discourse.org/t/configuring-twitter-login-for-discourse/13395" target="_blank">See this guide to learn more</a>.',
        )
      end
    end
  end
end

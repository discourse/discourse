# frozen_string_literal: true

describe GithubBadgesRepoSettingValidator do
  subject(:validator) { described_class.new }

  before { enable_current_plugin }

  describe "#valid_value?" do
    context "when a github URL is provided" do
      let(:value) { "https://github.com/discourse/discourse/" }

      it "is ok" do
        expect(validator.valid_value?(value)).to eq(true)
      end
    end

    context "when a github repo in the format user/repo is provided" do
      let(:value) { "discourse/discourse-github" }

      it "is ok" do
        expect(validator.valid_value?(value)).to eq(true)
      end
    end

    context "when a github repo name by itself is provided" do
      let(:value) { "some-repo" }

      it "is not ok" do
        expect(validator.valid_value?(value)).to eq(false)
      end
    end

    context "when multiple valid settings are provided" do
      let(:value) { "discourse/discourse-github|https://github.com/discourse/discourse/" }

      it "is ok" do
        expect(validator.valid_value?(value)).to eq(true)
      end
    end

    context "when multiple valid settings with one invalid setting is provided" do
      let(:value) { "discourse/discourse-github|https://github.com/discourse/discourse/|bad-dog" }

      it "is not ok" do
        expect(validator.valid_value?(value)).to eq(false)
      end
    end
  end

  describe "#error_message" do
    it "returns the generic message when no specific repo failed" do
      expect(validator.error_message).to eq(I18n.t("site_settings.errors.invalid_badge_repo"))
    end

    it "names the first invalid repo in a list" do
      value = "discourse/discourse-github|https://github.com/discourse/discourse/|bad-dog|nope"

      expect(validator.valid_value?(value)).to eq(false)
      expect(validator.error_message).to eq(
        I18n.t("site_settings.errors.invalid_badge_repo_value", repo: "bad-dog"),
      )
    end
  end
end

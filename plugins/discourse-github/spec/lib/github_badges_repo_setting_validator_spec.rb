# frozen_string_literal: true

require "rails_helper"

describe GithubBadgesRepoSettingValidator do
  subject(:validator) { described_class.new }

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
end

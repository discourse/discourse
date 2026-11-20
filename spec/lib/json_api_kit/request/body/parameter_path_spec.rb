# frozen_string_literal: true

RSpec.describe JsonApiKit::Request::Body::ParameterPath do
  subject(:path) { described_class.for(parameter) }

  let(:parameter) { :"user_ids[1]" }

  describe ".for" do
    context "when the parameter is already a path" do
      let(:parameter) { described_class.new(:user_ids) }

      it { is_expected.to equal(parameter) }
    end
  end

  describe "#name" do
    subject(:name) { path.name }

    it { is_expected.to eq(:user_ids) }

    context "when the parameter names a nested attribute" do
      let(:parameter) { "display_settings.theme" }

      it { is_expected.to eq(:display_settings) }
    end
  end

  describe "#index" do
    subject(:index) { path.index }

    it { is_expected.to eq(1) }

    context "when the index is dotted" do
      let(:parameter) { "user_ids.2" }

      it { is_expected.to eq(2) }
    end

    context "when the indexed member has a nested error" do
      let(:parameter) { :"users[1].username" }

      it { is_expected.to eq(1) }
    end

    context "when the parameter has no index" do
      let(:parameter) { :user_ids }

      it { is_expected.to be_nil }
    end

    context "when the nested member is not an index" do
      let(:parameter) { :"display_settings.theme" }

      it { is_expected.to be_nil }
    end
  end

  describe "#base?" do
    context "when the error applies to the whole contract" do
      let(:parameter) { :base }

      it { is_expected.to be_base }
    end

    context "when base names a nested member" do
      let(:parameter) { :"settings.base" }

      it { is_expected.not_to be_base }
    end
  end
end

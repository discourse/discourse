# frozen_string_literal: true

RSpec.describe JsonApiKit::MediaType do
  subject(:media_type) { described_class.new(declaration) }

  let(:declaration) { "application/vnd.api+json" }

  describe ".parse" do
    subject(:parsed) { described_class.parse(header) }

    let(:header) { "application/vnd.api+json;charset=utf-8, application/vnd.api+json" }

    it "returns one media type per instance of the header" do
      expect(parsed.size).to eq(2)
    end

    context "when the header is empty" do
      let(:header) { nil }

      it { is_expected.to be_empty }
    end
  end

  describe "#json_api?" do
    it { is_expected.to be_json_api }

    context "when the letters differ in case" do
      let(:declaration) { "Application/VND.api+JSON" }

      it { is_expected.to be_json_api }
    end

    context "when the media type is another one" do
      let(:declaration) { "text/csv" }

      it { is_expected.not_to be_json_api }
    end
  end

  describe "#modified?" do
    it { is_expected.not_to be_modified }

    context "when a profile is applied" do
      let(:declaration) { %(application/vnd.api+json;profile="https://a/b https://a/c") }

      it { is_expected.not_to be_modified }
    end

    context "when the instance carries a weight" do
      let(:declaration) { "application/vnd.api+json;q=0.9" }

      it { is_expected.not_to be_modified }
    end

    context "when another parameter follows the weight" do
      let(:declaration) { "application/vnd.api+json;q=0.9;charset=utf-8" }

      it { is_expected.to be_modified }
    end

    context "when another parameter comes first" do
      let(:declaration) { "application/vnd.api+json;charset=utf-8" }

      it { is_expected.to be_modified }
    end
  end

  describe "#extended?" do
    it { is_expected.not_to be_extended }

    context "when an extension is applied" do
      let(:declaration) { %(application/vnd.api+json;ext="https://a/b") }

      it { is_expected.to be_extended }
    end
  end
end

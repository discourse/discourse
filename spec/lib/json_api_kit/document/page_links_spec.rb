# frozen_string_literal: true

RSpec.describe JsonApiKit::Document::PageLinks do
  subject(:page_links) { described_class.new(url, pages) }

  let(:url) { JsonApiKit::Url.new("https://example.com/api/topics") }
  let(:pages) { { before: "read-back-here", after: "read-on-here" } }

  describe "#to_h" do
    subject(:links) { page_links.to_h }

    it "returns a link to the page at each end" do
      expect(links).to eq(
        prev: "https://example.com/api/topics?page[before]=read-back-here",
        next: "https://example.com/api/topics?page[after]=read-on-here",
      )
    end

    context "when no page follows the records" do
      let(:pages) { super().merge(after: nil) }

      it "returns no next link" do
        expect(links[:next]).to be_nil
      end
    end

    context "when no page comes before the records" do
      let(:pages) { super().merge(before: nil) }

      it "returns a next link only" do
        expect(links).to eq(
          prev: nil,
          next: "https://example.com/api/topics?page[after]=read-on-here",
        )
      end
    end

    context "when there is no page" do
      let(:pages) { {} }

      it { is_expected.to be_empty }
    end
  end
end

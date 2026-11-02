# frozen_string_literal: true

RSpec.describe JsonApiKit::Adapters::ActiveRecord::Page::Requested do
  describe ".from" do
    subject(:requested_page) { described_class.from(request, adapter:) }

    let(:request) { instance_double(JsonApiKit::Request::Collection, page: parameters, anchoring:) }
    let(:parameters) do
      { size: 2, after: nil, before: nil, include_anchor: nil, item_cursors: true }
    end
    let(:page_options) { { size: 2, after: nil, before: nil, anchoring: nil } }
    let(:anchoring) { nil }
    let(:adapter) { instance_double(JsonApiKit::Adapters::ActiveRecord) }
    let(:cursor) { instance_double(JsonApiKit::Adapters::ActiveRecord::Pagination::Cursor) }
    let(:raw_cursor) { "backend-cursor" }

    before do
      allow(described_class).to receive(:for).and_call_original
      allow(adapter).to receive(:parse_cursor).with(raw_cursor).and_return(cursor)
    end

    it "excludes representation options and omitted page values" do
      requested_page

      expect(described_class).to have_received(:for).with(**page_options)
    end

    context "when the page has an after cursor" do
      let(:parameters) { super().merge(after: raw_cursor) }
      let(:page_options) { super().merge(after: cursor) }

      it "uses the adapter's parsed cursor" do
        requested_page

        expect(described_class).to have_received(:for).with(**page_options)
      end
    end

    context "when the page has a before cursor" do
      let(:parameters) { super().merge(before: raw_cursor) }
      let(:page_options) { super().merge(before: cursor) }

      it "uses the adapter's parsed cursor" do
        requested_page

        expect(described_class).to have_received(:for).with(**page_options)
      end
    end

    context "when the page has an anchor" do
      let(:anchoring) { JsonApiKit::Anchoring.for(id: 12) }
      let(:parameters) do
        super().merge(anchor: { id: 12 }, before_size: 1, after_size: 1, include_anchor: false)
      end
      let(:page_options) do
        super().merge(anchoring:, before_size: 1, after_size: 1, include_anchor: false)
      end

      it "preserves the anchor and window options" do
        requested_page

        expect(described_class).to have_received(:for).with(**page_options)
      end
    end
  end
end

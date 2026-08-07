# frozen_string_literal: true

# The Kit's read API from the outside: what a caller asks a resource for, and what it gets back.
# Written before the objects behind it, so the shape of a request and of an answer are decided here
# rather than falling out of whatever the internals turned out to be.
#
# Parameters are JSON:API *concepts* in the shape our objects want, not JSON:API spelling: a
# controller validates `sort=-created_at` against the spec and hands over `sort: { created_at: :desc }`.
# Everything below the controller is spared string parsing, and the mapping stays free to change.
#
# Groups are marked pending until the slice that builds them is under way; a pending example that
# starts passing is reported as FIXED, which is when its marker comes off.
class ReadingSpecTopicResource < JsonApiKit::Resource
  model Topic
  type :topics

  sort :created_at
  sort :title
  default_sort created_at: :desc

  filter :title
end

RSpec.describe "reading through a resource" do
  subject(:listing) { resource.all(params, guardian:) }

  fab!(:oldest) do
    Fabricate(:topic, title: "Anchors and centred pages", created_at: Time.utc(2026, 8, 1))
  end
  fab!(:middle) do
    Fabricate(:topic, title: "Cursors that survive a redesign", created_at: Time.utc(2026, 8, 2))
  end
  fab!(:newest) do
    Fabricate(:topic, title: "Bands of a segmented listing", created_at: Time.utc(2026, 8, 3))
  end

  let(:resource) { ReadingSpecTopicResource }
  let(:guardian) { Guardian.new }
  let(:params) { {} }
  let(:listed) { listing.records.map(&:id) }

  describe "sorting" do
    let(:params) { { sort: { created_at: :asc } } }

    it "orders a listing by the sort a request names" do
      expect(listed).to eq([oldest.id, middle.id, newest.id])
    end

    context "when the request asks for the other direction" do
      let(:params) { { sort: { created_at: :desc } } }

      it "reads the listing that way" do
        expect(listed).to eq([newest.id, middle.id, oldest.id])
      end
    end

    context "when the request names several sorts" do
      let(:params) { { sort: { title: :asc, created_at: :desc } } }

      it "orders by each in the sequence it names them" do
        expect(listed).to eq([oldest.id, newest.id, middle.id])
      end
    end

    context "when the request names no sort" do
      let(:params) { {} }

      it "orders by what the resource declares" do
        expect(listed).to eq([newest.id, middle.id, oldest.id])
      end
    end

    context "when the request names a sort the resource never declared" do
      let(:params) { { sort: { secrets: :asc } } }

      it "refuses to read a listing nobody offered" do
        expect { listed }.to raise_error(JsonApiKit::Declarations::Sorts::Unsupported)
      end
    end
  end

  describe "paging", pending: "slice 1: page limits and cursor parameters" do
    let(:params) { { sort: { created_at: :asc }, page: { size: 2 } } }

    it "reads a page of the size the request asks for" do
      expect(listed).to eq([oldest.id, middle.id])
    end

    it "hands back a cursor the next page is read from" do
      expect(resource.all(params.deep_merge(page: { after: listing.next }), guardian:).records).to(
        eq([newest]),
      )
    end

    context "when the page holds the last row of the listing" do
      let(:params) { { sort: { created_at: :asc }, page: { size: 5 } } }

      it "names no next page" do
        expect(listing.next).to be_nil
      end
    end

    it "lets any row of a page be paged from" do
      expect(listing.rows.map(&:cursor)).to all(be_present)
    end

    context "when the size asked for is larger than the resource allows" do
      let(:params) { { page: { size: 5_000 } } }

      it "refuses to read the page" do
        expect { listed }.to raise_error(JsonApiKit::Declarations::PageLimits::TooLarge)
      end
    end
  end

  describe "the rows a resource exposes" do
    let(:resource) do
      Class.new(JsonApiKit::Resource) do
        model Topic
        type :topics
        scope { |guardian| Topic.secured(guardian).where(closed: true) }
      end
    end

    it "reads only the rows its scope allows" do
      expect(listing.records).to be_empty
    end

    context "when the resource declares no scope of its own" do
      let(:resource) { ReadingSpecTopicResource }

      it "reads every row of its model" do
        expect(listed).to contain_exactly(oldest.id, middle.id, newest.id)
      end
    end
  end

  describe "filtering" do
    let(:params) { { filter: { title: "Cursors that survive a redesign" } } }

    it "keeps the rows a declared filter allows" do
      expect(listed).to eq([middle.id])
    end

    context "when the request names a filter the resource never declared" do
      let(:params) { { filter: { secrets: "x" } } }

      it "refuses to read a listing nobody offered" do
        expect { listed }.to raise_error(JsonApiKit::Declarations::Filters::Unsupported)
      end
    end
  end

  describe "finding one", pending: "slice 1: reading a single resource" do
    it "returns the record the id names" do
      expect(resource.find(middle.id, guardian:).record).to eq(middle)
    end

    context "when the id names a row its scope does not expose" do
      it "refuses to read it" do
        expect { resource.find(-1, guardian:).record }.to raise_error(JsonApiKit::NotFound)
      end
    end
  end

  describe "the document", pending: "slice 1: document assembly" do
    let(:params) { { sort: { created_at: :asc }, fields: { topics: [:title] } } }

    it "renders each row as a resource object of the declared type" do
      expect(listing.document[:data].first).to include(type: "topics", id: oldest.id.to_s)
    end

    it "renders only the fields the request asked for" do
      expect(listing.document[:data].first[:attributes].keys).to contain_exactly(:title)
    end

    it "carries the cursor to page on from each row" do
      expect(listing.document[:data].first[:meta][:page][:cursor]).to be_present
    end
  end

  describe "sideloading", pending: "slice 1: relationships and included resources" do
    let(:params) { { include: ["user"] } }

    it "renders the related resources the request included" do
      expect(listing.document[:included].map { it[:type] }).to contain_exactly("users")
    end

    context "when the path names no relationship the resource declared" do
      let(:params) { { include: ["secrets"] } }

      it "refuses to render it" do
        expect { listing.document }.to raise_error(
          JsonApiKit::Declarations::IncludePaths::Unsupported,
        )
      end
    end
  end

  describe "reading as part of another listing" do
    it "reads only the rows that listing holds" do
      expect(resource.all({}, guardian:, scoped_to: Topic.where(id: middle.id)).records).to eq(
        [middle],
      )
    end
  end

  describe "anchors", pending: "slice 1: anchored and centred pages" do
    # Rows either side of the three the listing is built from, so a centred page is not the
    # whole listing and the example can tell the difference.
    fab!(:earliest) do
      Fabricate(:topic, title: "Before everything else", created_at: Time.utc(2026, 7, 31))
    end
    fab!(:latest) do
      Fabricate(:topic, title: "After everything else", created_at: Time.utc(2026, 8, 4))
    end

    let(:params) { { sort: { created_at: :asc }, anchor: { id: middle.id }, page: { size: 3 } } }

    it "reads a page centred on the row an anchor names" do
      expect(listed).to eq([oldest.id, middle.id, newest.id])
    end
  end
end

# frozen_string_literal: true

require_relative "support"

RSpec.describe "a listing read from a cursor" do
  include_context "with a listing of topics"

  let(:sort) { { created_at: :asc } }
  let(:cursor) { cursor_for(middle) }
  let(:sorted_listing) { listing_of({ sort: }) }
  let(:pages) do
    sorted_listing[:data].map do
      listing_of({ sort:, page: { after: cursor_of(it) }, fields: { topics: [:title] } })
    end
  end

  def cursor_for(record) = cursor_of(sorted_listing[:data].detect { it[:id] == record.id.to_s })

  it "reads a page from the cursor of every row" do
    expect(pages).to eq(
      [
        {
          data: [
            topic_object(middle, fields: %w[title], cursor: cursor_for(middle)),
            topic_object(newest, fields: %w[title], cursor: cursor_for(newest)),
          ],
          included: [],
          links: links_of(prev: page_url(before: cursor_for(middle))),
        },
        {
          data: [topic_object(newest, fields: %w[title], cursor: cursor_for(newest))],
          included: [],
          links: links_of(prev: page_url(before: cursor_for(newest))),
        },
        { data: [], included: [], links: links_of(prev: page_url(before: cursor_for(newest))) },
      ],
    )
  end

  context "when the request holds page[after]" do
    let(:params) { { sort:, page: { after: cursor }, fields: { topics: [:title] } } }

    it "returns the rows after the cursor" do
      expect(document).to eq(
        data: [topic_object(newest, fields: %w[title], cursor: cursor_for(newest))],
        included: [],
        links: links_of(prev: page_url(before: cursor_for(newest))),
      )
    end
  end

  context "when the request holds page[before]" do
    let(:params) { { sort:, page: { before: cursor }, fields: { topics: [:title] } } }

    it "returns the rows before the cursor" do
      expect(document).to eq(
        data: [topic_object(oldest, fields: %w[title], cursor: cursor_for(oldest))],
        included: [],
        links: links_of(next: page_url(after: cursor_for(oldest))),
      )
    end
  end

  context "when the sort is created_at desc" do
    let(:sort) { { created_at: :desc } }
    let(:params) { { sort:, page: { after: cursor }, fields: { topics: [:title] } } }

    it "returns the rows after the cursor" do
      expect(document).to eq(
        data: [topic_object(oldest, fields: %w[title], cursor: cursor_for(oldest))],
        included: [],
        links: links_of(prev: page_url(before: cursor_for(oldest))),
      )
    end
  end

  context "when the cursor comes from a backwards page" do
    let(:cursor) { cursor_at(0, listing_of({ sort:, page: { before: super() } })) }
    let(:params) { { sort:, page: { after: cursor }, fields: { topics: [:title] } } }

    it "returns the rows after the cursor" do
      expect(document).to eq(
        data: [
          topic_object(middle, fields: %w[title], cursor: cursor_for(middle)),
          topic_object(newest, fields: %w[title], cursor: cursor_for(newest)),
        ],
        included: [],
        links: links_of(prev: page_url(before: cursor_for(middle))),
      )
    end
  end

  context "when the cursor comes from the last row" do
    let(:cursor) { cursor_for(newest) }
    let(:params) { { sort:, page: { after: cursor }, fields: { topics: [:title] } } }

    it "returns no row and links to no next page" do
      expect(document).to eq(
        data: [],
        included: [],
        links: links_of(prev: page_url(before: cursor)),
      )
    end
  end

  context "when the sort is last_posted_at and one row holds none" do
    fab!(:never_posted) do
      Fabricate(:topic, title: "Nothing has been posted here", last_posted_at: nil)
    end

    before { [oldest, middle, newest].each { it.update_columns(last_posted_at: it.created_at) } }

    let(:sort) { { last_posted_at: :asc } }

    context "when the cursor comes from the last row holding a value" do
      let(:cursor) { cursor_for(newest) }
      let(:params) { { sort:, page: { after: cursor }, fields: { topics: [:title] } } }

      it "returns the row holding no value" do
        expect(document).to eq(
          data: [topic_object(never_posted, fields: %w[title], cursor: cursor_for(never_posted))],
          included: [],
          links: links_of(prev: page_url(before: cursor_for(never_posted))),
        )
      end
    end

    context "when the cursor comes from the row holding no value" do
      let(:cursor) { cursor_for(never_posted) }
      let(:params) { { sort:, page: { before: cursor }, fields: { topics: [:title] } } }

      it "returns the rows holding a value" do
        expect(document).to eq(
          data: [
            topic_object(oldest, fields: %w[title], cursor: cursor_for(oldest)),
            topic_object(middle, fields: %w[title], cursor: cursor_for(middle)),
            topic_object(newest, fields: %w[title], cursor: cursor_for(newest)),
          ],
          included: [],
          links: links_of(next: page_url(after: cursor_for(newest))),
        )
      end
    end

    context "when the request sorts by created_at" do
      let(:cursor) { cursor_for(never_posted) }
      let(:params) do
        { sort: { created_at: :asc }, page: { after: cursor }, fields: { topics: [:title] } }
      end

      it "refuses the cursor" do
        expect(document).to eq(
          errors: [
            refusal(
              title: "Cursor does not match the sort",
              detail: "This cursor comes from a different sort.",
              parameter: "page[after]",
            ),
          ],
        )
      end
    end
  end
end

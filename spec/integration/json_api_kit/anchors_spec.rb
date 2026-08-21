# frozen_string_literal: true

require_relative "support"

RSpec.describe "a listing entered at an anchor" do
  include_context "with a listing of topics"

  fab!(:earliest) do
    Fabricate(:topic, title: "Before everything else", created_at: Time.utc(2026, 7, 31))
  end
  fab!(:latest) do
    Fabricate(:topic, title: "After everything else", created_at: Time.utc(2026, 8, 4))
  end

  let(:params) do
    {
      sort: {
        created_at: :asc,
      },
      anchor: {
        id: middle.id,
      },
      page: {
        before_size: 1,
        after_size: 1,
      },
      fields: {
        topics: [:title],
      },
    }
  end

  it "returns a page centred on the anchor row" do
    expect(document).to eq(
      data: [
        topic_object(oldest, fields: %w[title], cursor: cursor_at(0)),
        topic_object(middle, fields: %w[title], cursor: cursor_at(1)),
        topic_object(newest, fields: %w[title], cursor: cursor_at(2)),
      ],
      included: [],
      links: links_of(prev: page_url(before: cursor_at(0)), next: page_url(after: cursor_at(2))),
    )
  end

  context "when the page has a size alone" do
    let(:params) do
      {
        sort: {
          created_at: :asc,
        },
        anchor: {
          id: middle.id,
        },
        page: {
          size: 2,
        },
        fields: {
          topics: [:title],
        },
      }
    end

    it "returns that many rows from the anchor row" do
      expect(document).to eq(
        data: [
          topic_object(middle, fields: %w[title], cursor: cursor_at(0)),
          topic_object(newest, fields: %w[title], cursor: cursor_at(1)),
        ],
        included: [],
        links: links_of(prev: page_url(before: cursor_at(0)), next: page_url(after: cursor_at(1))),
      )
    end
  end

  context "when the anchor is a value of the sort" do
    let(:params) do
      {
        sort: {
          created_at: :asc,
        },
        anchor: {
          created_at: Time.utc(2026, 8, 2),
        },
        page: {
          size: 2,
        },
        fields: {
          topics: [:title],
        },
      }
    end

    it "starts at the row holding that value" do
      expect(document).to eq(
        data: [
          topic_object(middle, fields: %w[title], cursor: cursor_at(0)),
          topic_object(newest, fields: %w[title], cursor: cursor_at(1)),
        ],
        included: [],
        links: links_of(prev: page_url(before: cursor_at(0)), next: page_url(after: cursor_at(1))),
      )
    end
  end

  context "when no row holds the anchor value" do
    let(:params) do
      {
        sort: {
          created_at: :asc,
        },
        anchor: {
          created_at: Time.utc(2026, 8, 1, 12),
        },
        page: {
          size: 2,
        },
        fields: {
          topics: [:title],
        },
      }
    end

    it "starts at the first row past it" do
      expect(document).to eq(
        data: [
          topic_object(middle, fields: %w[title], cursor: cursor_at(0)),
          topic_object(newest, fields: %w[title], cursor: cursor_at(1)),
        ],
        included: [],
        links: links_of(prev: page_url(before: cursor_at(0)), next: page_url(after: cursor_at(1))),
      )
    end
  end

  context "when the anchor value is past every row holding one" do
    fab!(:never_posted) do
      Fabricate(:topic, title: "Nothing has been posted here", last_posted_at: nil)
    end

    let(:params) do
      {
        sort: {
          last_posted_at: :asc,
        },
        anchor: {
          last_posted_at: Time.utc(2030, 1, 1),
        },
        page: {
          size: 1,
        },
        fields: {
          topics: [:title],
        },
      }
    end

    before do
      [earliest, oldest, middle, newest, latest].each do |topic|
        topic.update_columns(last_posted_at: topic.created_at)
      end
    end

    it "starts at the first row holding none" do
      expect(document).to eq(
        data: [topic_object(never_posted, fields: %w[title], cursor: cursor_at(0))],
        included: [],
        links: links_of(prev: page_url(before: cursor_at(0))),
      )
    end
  end

  context "when the server calculates the anchor" do
    let(:guardian) { Guardian.new(middle.user) }
    let(:params) do
      { sort: { created_at: :asc }, anchor: :mine, page: { size: 1 }, fields: { topics: [:title] } }
    end

    it "starts at the row it finds for the current user" do
      expect(document).to eq(
        data: [topic_object(middle, fields: %w[title], cursor: cursor_at(0))],
        included: [],
        links: links_of(prev: page_url(before: cursor_at(0)), next: page_url(after: cursor_at(0))),
      )
    end

    context "when the calculated anchor holds no row" do
      let(:guardian) { Guardian.new }

      it "starts at the first row of the listing" do
        expect(document).to eq(
          data: [topic_object(earliest, fields: %w[title], cursor: cursor_at(0))],
          included: [],
          links: links_of(next: page_url(after: cursor_at(0))),
        )
      end
    end
  end

  context "when the anchor is an id no row holds" do
    let(:params) { { sort: { created_at: :asc }, anchor: { id: -1 } } }

    it "renders the error as a document" do
      expect(document).to eq(
        errors: [
          refusal(
            title: "No row for the anchor",
            detail: "No record has id -1.",
            parameter: "anchor[id]",
          ),
        ],
      )
    end
  end

  context "when the anchor is on another sort" do
    let(:params) { { sort: { created_at: :asc }, anchor: { title: middle.title } } }

    it "renders the error as a document" do
      expect(document).to eq(
        errors: [
          refusal(
            title: "Anchor does not match the sort",
            detail: "The anchor is title, but this request sorts by created_at.",
            parameter: "anchor[title]",
          ),
        ],
      )
    end
  end

  describe "the window either side of the anchor" do
    context "when the window is larger than the maximum" do
      let(:params) do
        {
          sort: {
            created_at: :asc,
          },
          anchor: {
            id: middle.id,
          },
          page: {
            before_size: 3_000,
            after_size: 3_000,
          },
        }
      end

      it "renders the error as a document" do
        expect(document).to eq(
          errors: [
            refusal(
              title: "Window is too large",
              detail: "A window of 6001 rows exceeds the maximum of 100.",
              parameter: "page[before_size]",
              links: {
                type: profile_link("max-size-exceeded"),
              },
              meta: {
                page: {
                  maxSize: 100,
                },
              },
            ),
          ],
        )
      end
    end

    context "when the window is empty" do
      let(:params) do
        {
          anchor: {
            id: middle.id,
          },
          page: {
            before_size: 0,
            after_size: 0,
            include_anchor: false,
          },
        }
      end

      it "renders the error as a document" do
        expect(document).to eq(
          errors: [
            refusal(
              title: "Window is empty",
              detail: "A window must be at least 1 row.",
              parameter: "page[before_size]",
            ),
          ],
        )
      end
    end

    context "when a side of the window is negative" do
      let(:params) { { anchor: { id: middle.id }, page: { before_size: -1, after_size: 2 } } }

      it "renders the error as a document" do
        expect(document).to eq(
          errors: [
            refusal(
              title: "Window size is negative",
              detail: "page[before_size] must be 0 or greater.",
              parameter: "page[before_size]",
            ),
          ],
        )
      end
    end

    context "when a side of the window is not an integer" do
      let(:params) { { anchor: { id: middle.id }, page: { after_size: "two" } } }

      it "renders the error as a document" do
        expect(document).to eq(
          errors: [
            refusal(
              title: "Window size is not an integer",
              detail: "page[after_size] must be an integer.",
              parameter: "page[after_size]",
            ),
          ],
        )
      end
    end
  end
end

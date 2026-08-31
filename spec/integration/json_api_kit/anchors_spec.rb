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
      page: {
        anchor: {
          id: middle.id,
        },
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
        topic_object(oldest, fields: %w[title]),
        topic_object(middle, fields: %w[title]),
        topic_object(newest, fields: %w[title]),
      ],
      included: [],
      links:
        links_of(
          prev: page_url(before: cursor_of_record(oldest, sort: { created_at: :asc })),
          next: page_url(after: cursor_of_record(newest, sort: { created_at: :asc })),
        ),
    )
  end

  context "when the page has a size alone" do
    let(:params) do
      {
        sort: {
          created_at: :asc,
        },
        page: {
          anchor: {
            id: middle.id,
          },
          size: 2,
        },
        fields: {
          topics: [:title],
        },
      }
    end

    it "returns that many rows from the anchor row" do
      expect(document).to eq(
        data: [topic_object(middle, fields: %w[title]), topic_object(newest, fields: %w[title])],
        included: [],
        links:
          links_of(
            prev: page_url(before: cursor_of_record(middle, sort: { created_at: :asc })),
            next: page_url(after: cursor_of_record(newest, sort: { created_at: :asc })),
          ),
      )
    end
  end

  context "when the anchor is a value of the sort" do
    let(:params) do
      {
        sort: {
          created_at: :asc,
        },
        page: {
          anchor: {
            created_at: Time.utc(2026, 8, 2),
          },
          size: 2,
        },
        fields: {
          topics: [:title],
        },
      }
    end

    it "starts at the row holding that value" do
      expect(document).to eq(
        data: [topic_object(middle, fields: %w[title]), topic_object(newest, fields: %w[title])],
        included: [],
        links:
          links_of(
            prev: page_url(before: cursor_of_record(middle, sort: { created_at: :asc })),
            next: page_url(after: cursor_of_record(newest, sort: { created_at: :asc })),
          ),
      )
    end
  end

  context "when no row holds the anchor value" do
    let(:params) do
      {
        sort: {
          created_at: :asc,
        },
        page: {
          anchor: {
            created_at: Time.utc(2026, 8, 1, 12),
          },
          size: 2,
        },
        fields: {
          topics: [:title],
        },
      }
    end

    it "starts at the first row past it" do
      expect(document).to eq(
        data: [topic_object(middle, fields: %w[title]), topic_object(newest, fields: %w[title])],
        included: [],
        links:
          links_of(
            prev: page_url(before: cursor_of_record(middle, sort: { created_at: :asc })),
            next: page_url(after: cursor_of_record(newest, sort: { created_at: :asc })),
          ),
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
        page: {
          anchor: {
            last_posted_at: Time.utc(2030, 1, 1),
          },
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
        data: [topic_object(never_posted, fields: %w[title])],
        included: [],
        links:
          links_of(
            prev: page_url(before: cursor_of_record(never_posted, sort: { last_posted_at: :asc })),
          ),
      )
    end

    context "when every row holds one" do
      before { never_posted.update_columns(last_posted_at: Time.utc(2026, 8, 6)) }

      it "returns no row" do
        expect(listed_ids).to be_empty
      end
    end

    context "when the nulls read first" do
      let(:resource) do
        Class.new(JsonApiKit::Resource) do
          model Topic
          type :topics
          attribute :title
          sort :last_posted_at, nulls: :first
          default_sort last_posted_at: :asc
          anchor :last_posted_at
        end
      end

      it "returns no row" do
        expect(listed_ids).to be_empty
      end

      context "when every row holds one" do
        before { never_posted.update_columns(last_posted_at: Time.utc(2026, 8, 6)) }

        it "returns no row" do
          expect(listed_ids).to be_empty
        end
      end
    end
  end

  context "when the server calculates the anchor" do
    let(:guardian) { Guardian.new(middle.user) }
    let(:params) do
      { sort: { created_at: :asc }, page: { anchor: :mine, size: 1 }, fields: { topics: [:title] } }
    end

    it "starts at the row it finds for the current user" do
      expect(document).to eq(
        data: [topic_object(middle, fields: %w[title])],
        included: [],
        links:
          links_of(
            prev: page_url(before: cursor_of_record(middle, sort: { created_at: :asc })),
            next: page_url(after: cursor_of_record(middle, sort: { created_at: :asc })),
          ),
      )
    end

    context "when the calculated anchor holds no row" do
      let(:guardian) { Guardian.new }

      it "starts at the first row of the listing" do
        expect(document).to eq(
          data: [topic_object(earliest, fields: %w[title])],
          included: [],
          links:
            links_of(next: page_url(after: cursor_of_record(earliest, sort: { created_at: :asc }))),
        )
      end
    end
  end

  context "when the anchor is an id no row holds" do
    let(:params) { { sort: { created_at: :asc }, page: { anchor: { id: -1 } } } }

    it "renders the error as a document" do
      expect(document).to eq(
        errors: [
          refusal(
            title: "No row for the anchor",
            detail: "No record has id -1.",
            parameter: "page[anchor][id]",
          ),
        ],
      )
    end
  end

  context "when the anchor is on another sort" do
    let(:params) { { sort: { created_at: :asc }, page: { anchor: { title: middle.title } } } }

    it "renders the error as a document" do
      expect(document).to eq(
        errors: [
          refusal(
            title: "Anchor does not match the sort",
            detail: "The anchor is title, but this request sorts by created_at.",
            parameter: "page[anchor][title]",
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
          page: {
            anchor: {
              id: middle.id,
            },
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
          page: {
            anchor: {
              id: middle.id,
            },
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
      let(:params) { { page: { anchor: { id: middle.id }, before_size: -1, after_size: 2 } } }

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
      let(:params) { { page: { anchor: { id: middle.id }, after_size: "two" } } }

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

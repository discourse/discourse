# frozen_string_literal: true

require_relative "support"

RSpec.describe "a refused request" do
  include_context "with a listing of topics"

  let(:cursor) { cursor_of_record(middle) }

  describe "the sort parameter" do
    context "when the sort is a string" do
      let(:params) { { sort: "created_at" } }

      it "refuses the sort" do
        expect(document).to eq(
          errors: [
            refusal(
              title: "Invalid sort parameter",
              detail: "sort must name a direction for each sort.",
              parameter: "sort",
            ),
          ],
        )
      end
    end

    context "when the resource declares no such sort" do
      let(:params) { { sort: { secrets: :asc } } }

      it "refuses the sort" do
        expect(document).to eq(
          errors: [
            refusal(
              title: "No such sort",
              detail: "There is no sort named secrets.",
              parameter: "sort",
            ),
          ],
        )
      end

      it "answers the status 400" do
        expect(
          JsonApiKit::Document::Collection.for(params, resource:, guardian:, urls:).status,
        ).to eq("400")
      end
    end

    context "when the sort direction is neither asc nor desc" do
      let(:params) { { sort: { created_at: :sideways } } }

      it "refuses the sort" do
        expect(document).to eq(
          errors: [
            refusal(
              title: "No such sort direction",
              detail: "Sort direction sideways is not asc or desc.",
              parameter: "sort",
            ),
          ],
        )
      end
    end

    context "when an undeclared sort comes with an anchor" do
      let(:params) { { sort: { secrets: :asc }, anchor: { title: middle.title } } }

      it "refuses the sort alone" do
        expect(document).to eq(
          errors: [
            refusal(
              title: "No such sort",
              detail: "There is no sort named secrets.",
              parameter: "sort",
            ),
          ],
        )
      end
    end

    context "when an undeclared sort comes with a cursor" do
      let(:params) { { sort: { secrets: :asc }, page: { after: cursor } } }

      it "refuses the sort alone" do
        expect(document).to eq(
          errors: [
            refusal(
              title: "No such sort",
              detail: "There is no sort named secrets.",
              parameter: "sort",
            ),
          ],
        )
      end
    end

    context "when a request for one record has a sort" do
      let(:params) { { sort: { created_at: :asc } } }

      it "refuses the sort" do
        expect(one_document(middle.id)).to eq(
          errors: [
            refusal(
              title: "No such parameter",
              detail: "There is no parameter named sort.",
              parameter: "sort",
            ),
          ],
        )
      end
    end
  end

  describe "the filter parameter" do
    context "when the filter is a string" do
      let(:params) { { filter: "title" } }

      it "refuses the filter" do
        expect(document).to eq(
          errors: [
            refusal(
              title: "Invalid filter parameter",
              detail: "filter must name a value for each filter.",
              parameter: "filter",
            ),
          ],
        )
      end
    end

    context "when the resource declares no such filter" do
      let(:params) { { filter: { secrets: "hidden" } } }

      it "refuses the filter" do
        expect(document).to eq(
          errors: [
            refusal(
              title: "No such filter",
              detail: "There is no filter named secrets.",
              parameter: "filter[secrets]",
            ),
          ],
        )
      end
    end

    context "when the filter value is an empty set" do
      let(:params) { { filter: { title: {} } } }

      it "refuses the filter value" do
        expect(document).to eq(
          errors: [
            refusal(
              title: "Invalid filter value",
              detail: "filter[title] must be a value or a list of values.",
              parameter: "filter[title]",
            ),
          ],
        )
      end
    end

    context "when the filter value is a set of values" do
      let(:params) { { filter: { title: { like: "a topic" } } } }

      it "refuses the filter value" do
        expect(document).to eq(
          errors: [
            refusal(
              title: "Invalid filter value",
              detail: "filter[title] must be a value or a list of values.",
              parameter: "filter[title]",
            ),
          ],
        )
      end
    end
  end

  describe "the fields parameter" do
    context "when the fields are a string" do
      let(:params) { { fields: "title" } }

      it "refuses the fields" do
        expect(document).to eq(
          errors: [
            refusal(
              title: "Invalid fields parameter",
              detail: "fields must name a list of fields for each type.",
              parameter: "fields",
            ),
          ],
        )
      end
    end

    context "when the fieldset of a type is a string" do
      let(:params) { { fields: { topics: "title" } } }

      it "refuses the fieldset" do
        expect(document).to eq(
          errors: [
            refusal(
              title: "Invalid fields value",
              detail: "fields[topics] must be a list of field names.",
              parameter: "fields[topics]",
            ),
          ],
        )
      end
    end
  end

  describe "the include parameter" do
    context "when the resource declares no such path" do
      let(:params) { { include: %w[secrets] } }

      it "refuses the path" do
        expect(document).to eq(
          errors: [
            refusal(
              title: "No such relationship path",
              detail: "There is no relationship path named secrets.",
              parameter: "include",
            ),
          ],
        )
      end
    end
  end

  describe "an unknown parameter" do
    context "when the parameter is at the top level" do
      let(:params) { { sorts: { created_at: :asc } } }

      it "refuses the parameter" do
        expect(document).to eq(
          errors: [
            refusal(
              title: "No such parameter",
              detail: "There is no parameter named sorts.",
              parameter: "sorts",
            ),
          ],
        )
      end
    end

    context "when the parameter is under page" do
      let(:params) { { page: { sise: 2 } } }

      it "refuses the parameter" do
        expect(document).to eq(
          errors: [
            refusal(
              title: "No such parameter",
              detail: "There is no parameter named page[sise].",
              parameter: "page[sise]",
            ),
          ],
        )
      end
    end
  end

  describe "the page parameter" do
    context "when the page is a string" do
      let(:params) { { page: "big" } }

      it "refuses the page" do
        expect(document).to eq(
          errors: [
            refusal(
              title: "Invalid page parameter",
              detail: "page must name page parameters, as in page[size]=2.",
              parameter: "page",
            ),
          ],
        )
      end
    end

    context "when the page size is not a number" do
      let(:params) { { page: { size: "two" } } }

      it "refuses the page size" do
        expect(document).to eq(
          errors: [
            refusal(
              title: "Page size is not an integer",
              detail: "Page size must be an integer.",
              parameter: "page[size]",
            ),
          ],
        )
      end
    end

    context "when the page size is 0" do
      let(:params) { { page: { size: 0 } } }

      it "refuses the page size" do
        expect(document).to eq(
          errors: [
            refusal(
              title: "Page size is too small",
              detail: "Page size must be at least 1.",
              parameter: "page[size]",
            ),
          ],
        )
      end
    end

    context "when the page size is above the maximum" do
      let(:params) { { page: { size: 5_000 } } }

      it "refuses the page size" do
        expect(document).to eq(
          errors: [
            refusal(
              title: "Page size is too large",
              detail: "Page size 5000 exceeds the maximum of 100.",
              parameter: "page[size]",
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

    context "when the cursor is not base64" do
      let(:params) { { page: { after: "not-a-cursor" } } }

      it "refuses the cursor" do
        expect(document).to eq(
          errors: [
            refusal(
              title: "Invalid cursor",
              detail: "Use a cursor from this API.",
              parameter: "page[after]",
            ),
          ],
        )
      end
    end

    context "when the cursor comes from another sort" do
      let(:params) do
        {
          sort: {
            created_at: :asc,
          },
          page: {
            after: JsonApiKit::Pagination::Cursor.new([1, middle.id]).to_s,
          },
        }
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

    context "when a cursor is at both ends of the page" do
      let(:params) { { page: { after: cursor, before: cursor } } }

      it "refuses both parameters" do
        expect(document).to eq(
          errors:
            %w[page[after] page[before]].map do
              refusal(
                title: "Range pagination is not supported",
                detail: "Use page[after] or page[before], not both.",
                parameter: it,
                links: {
                  type: profile_link("range-pagination-not-supported"),
                },
              )
            end,
        )
      end
    end
  end

  describe "the window parameters" do
    context "when the request has no anchor" do
      let(:params) { { page: { before_size: 2, after_size: 2 } } }

      it "refuses the window" do
        expect(document).to eq(
          errors: [
            refusal(
              title: "Anchor is required",
              detail: "page[before_size], page[after_size] need an anchor.",
              parameter: "anchor",
            ),
          ],
        )
      end
    end

    context "when the window is above the maximum" do
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

      it "refuses the window" do
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

      it "refuses the window" do
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

      it "refuses the window" do
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

    context "when a side of the window is not a number" do
      let(:params) { { anchor: { id: middle.id }, page: { after_size: "two" } } }

      it "refuses the window" do
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

  describe "the anchor parameter" do
    context "when the resource declares no such anchor" do
      let(:params) { { anchor: { views: 1 } } }

      it "refuses the anchor" do
        expect(document).to eq(
          errors: [
            refusal(
              title: "No such anchor",
              detail: "There is no anchor named views.",
              parameter: "anchor[views]",
            ),
          ],
        )
      end
    end

    context "when the request has two anchors" do
      let(:params) { { anchor: { id: 1, title: "a topic" } } }

      it "refuses the anchor" do
        expect(document).to eq(
          errors: [
            refusal(
              title: "Too many anchors",
              detail: "Use one anchor only. This request has 2.",
              parameter: "anchor",
            ),
          ],
        )
      end
    end

    context "when the anchor value is a list" do
      let(:params) { { anchor: { id: [1, 2] } } }

      it "refuses the anchor value" do
        expect(document).to eq(
          errors: [
            refusal(
              title: "Invalid anchor value",
              detail: "anchor[id] must be a single value.",
              parameter: "anchor[id]",
            ),
          ],
        )
      end
    end

    context "when the anchor value is not a number" do
      let(:params) { { sort: { created_at: :asc }, anchor: { id: "not a number" } } }

      it "refuses the anchor value" do
        expect(document).to eq(
          errors: [
            refusal(
              title: "No row for the anchor",
              detail: "No record has id \"not a number\".",
              parameter: "anchor[id]",
            ),
          ],
        )
      end
    end

    context "when no row has the anchor id" do
      let(:params) { { sort: { created_at: :asc }, anchor: { id: -1 } } }

      it "refuses the anchor value" do
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

    context "when the anchor is not the sort" do
      let(:params) { { sort: { created_at: :asc }, anchor: { title: middle.title } } }

      it "refuses the anchor" do
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

    context "when the request has an anchor and a cursor" do
      let(:params) { { anchor: { id: oldest.id }, page: { after: cursor } } }

      it "refuses the anchor" do
        expect(document).to eq(
          errors: [
            refusal(
              title: "Anchor and cursor cannot be combined",
              detail: "Use anchor or page[after], not both.",
              parameter: "anchor",
            ),
          ],
        )
      end
    end
  end

  describe "a refusal a caller never sees" do
    context "when a related resource sorts by a column that can be null" do
      let(:resource) do
        related =
          Class.new(JsonApiKit::Resource) do
            model Post
            type :posts
            attribute :post_number
            sort :edited_at, column: :last_editor_edited_at, nulls: :last
            default_sort edited_at: :desc
          end

        Class.new(JsonApiKit::Resource) do
          model Topic
          type :topics
          attribute :title
          has_many :posts, resource: related
        end
      end
      let(:params) { { include: %w[posts] } }

      it "raises a split order error" do
        expect { document }.to raise_error(
          JsonApiKit::Pagination::PagePerOwner::SplitOrder,
          /edited_at/,
        )
      end
    end

    context "when the anchor is not the sort" do
      let(:params) { { sort: { created_at: :asc }, anchor: { title: middle.title } } }

      it "raises on a direct read" do
        expect { resource.all(params, guardian:).records }.to raise_error(ArgumentError, /title/)
      end
    end
  end
end

# frozen_string_literal: true

# Positional entry (docs/versioning-design.md §2c): enter an ordered list at an
# arbitrary position, then navigate both ways over the whole set — what a
# permalink into a long list needs, and what opaque cursors alone cannot express.
#
# The rule under test: an anchor resolves to a RECORD, and the cursor is minted
# from that record. Identity anchors (`page[anchor][id]`) therefore work under any
# ordering, including groups no value can name (the NULL tail); value anchors bound
# the leading sort column, so they must name the active sort.
RSpec.describe "JSON:API Kit anchored pagination" do
  fab!(:admin)
  fab!(:mango) do
    Fabricate(:query, name: "Mango", hidden: false, last_run_at: Time.utc(2026, 7, 2, 10))
  end
  fab!(:alpha) do
    Fabricate(:query, name: "Alpha", hidden: false, last_run_at: Time.utc(2026, 7, 1, 10))
  end
  fab!(:zulu) { Fabricate(:query, name: "Zulu", hidden: false, last_run_at: nil) }

  let(:parsed_document) { JSON.parse(response.body) }
  let(:returned_names) { parsed_document["data"].map { it.dig("attributes", "name") } }

  before do
    SiteSetting.data_explorer_enabled = true
    sign_in(admin)
  end

  def get_queries(params)
    get "/data-explorer/api/queries",
        params: params,
        headers: {
          "Accept" => "application/vnd.api+json",
          "Api-Version" => "2026-07-08",
        }
  end

  # Default sort is `ran_at: :desc` with nulls last → Mango, Alpha, Zulu.
  describe "anchoring by identity" do
    it "starts the window at the anchored record" do
      get_queries(page: { anchor: { id: alpha.id }, size: 2 })
      expect(returned_names).to eq(%w[Alpha Zulu])
    end

    it "offers a link back to what precedes it" do
      get_queries(page: { anchor: { id: alpha.id }, size: 2 })
      expect(parsed_document.dig("links", "prev")).to be_present
    end

    it "lets the client walk backwards from there" do
      get_queries(page: { anchor: { id: alpha.id }, size: 2 })
      get parsed_document.dig("links", "prev"),
          headers: {
            "Accept" => "application/vnd.api+json",
            "Api-Version" => "2026-07-08",
          }
      # Re-read the body: `parsed_document` memoizes the first response.
      names = JSON.parse(response.body)["data"].map { it.dig("attributes", "name") }
      expect(names).to eq(%w[Mango])
    end

    # The reason identity anchoring is the general case: with nulls last, no date
    # names the never-run group, and a composed keyset's leading column can be
    # synthetic (a pin flag), which no client could supply.
    it "reaches a row in the NULL group" do
      get_queries(sort: "-ran_at", page: { anchor: { id: zulu.id }, size: 1 })
      expect(returned_names).to eq(%w[Zulu])
    end
  end

  describe "anchoring by value" do
    it "starts at the first row at or after the value, ascending" do
      get_queries(sort: "name", page: { anchor: { name: "M" }, size: 2 })
      expect(returned_names).to eq(%w[Mango Zulu])
    end

    # Descending sort means the bound is `<=`, not `>=`.
    it "follows the sort direction, not the word 'after'" do
      get_queries(sort: "-ran_at", page: { anchor: { ran_at: "2026-07-01T10:00:00Z" }, size: 2 })
      expect(returned_names).to eq(%w[Alpha Zulu])
    end

    it "lands on the next row when the value matches nothing exactly" do
      get_queries(sort: "name", page: { anchor: { name: "B" }, size: 1 })
      expect(returned_names).to eq(%w[Mango])
    end

    it "rejects an anchor that isn't the leading sort" do
      get_queries(sort: "name", page: { anchor: { ran_at: "2026-07-01T10:00:00Z" } })
      expect(response.status).to eq(400)
    end

    it "rejects a value past the end of the list" do
      get_queries(sort: "name", page: { anchor: { name: "zzz" } })
      expect(response.status).to eq(400)
    end
  end

  describe "rejections" do
    it "rejects an undeclared anchor" do
      get_queries(page: { anchor: { nonsense: "1" } })
      expect(response.status).to eq(400)
    end

    it "rejects an anchor combined with a cursor" do
      get_queries(page: { anchor: { id: alpha.id }, after: "whatever" })
      expect(response.status).to eq(400)
    end
  end
end

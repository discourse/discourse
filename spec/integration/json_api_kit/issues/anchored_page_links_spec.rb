# frozen_string_literal: true

require_relative "../support"

# Url#at only removes the cursors from the request parameters. A next link
# built from an anchored window keeps `page[anchor]` and the window sizes
# and adds `page[after]`. The contract rejects that combination. So a client
# follows the link the document gave it and gets a 400.
#
# Fix: when building a page link, drop the anchor and the window sizes along
# with the cursors, so the link carries the cursor alone.
RSpec.describe "Following the next link of an anchored page" do
  include_context "with a listing of topics"

  fab!(:beyond) { Fabricate(:topic, created_at: Time.utc(2026, 7, 30)) }
  fab!(:further) { Fabricate(:topic, created_at: Time.utc(2026, 7, 29)) }

  let(:params) do
    {
      "page" => {
        "anchor" => {
          "id" => middle.id.to_s,
        },
        "before_size" => "1",
        "after_size" => "1",
      },
    }
  end
  let(:query) { params }

  it "answers with a document, not a refusal" do
    next_url = document.dig(:links, :next)
    followed = Rack::Utils.parse_nested_query(URI.parse(next_url).query)
    expect(listing_of(followed)[:errors]).to be_nil
  end
end

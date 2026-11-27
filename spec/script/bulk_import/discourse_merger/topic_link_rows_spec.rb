# frozen_string_literal: true

require_relative "../../../../script/bulk_import/discourse_merger/support"
require_relative "../../../../script/bulk_import/discourse_merger/topic_link_rows"

RSpec.describe BulkImport::DiscourseMerge::TopicLinkRows do
  it "combines resolved URLs in the same post, retaining the first row and every click" do
    writes = []
    links = described_class.new { |row| writes << row }
    first = { "id" => 7, "topic_id" => 8, "post_id" => 9, "url" => "/t/10/1", "clicks" => "1" }
    links.call(first.dup)
    links.call(first.merge("id" => 8, "url" => "/t/11/1", "clicks" => "4"))
    expect(links.call(first.merge("id" => 9))).to include("id" => 7, "clicks" => 2)
    links.call(first.merge("id" => 10, "post_id" => 10, "clicks" => "3"))
    links.flush
    expect(writes.map { |row| [row["id"], row["clicks"].to_i] }).to eq([[7, 2], [8, 4], [10, 3]])
  end

  it "preserves topic-only records with no associated post" do
    writes = []
    links = described_class.new { |row| writes << row }
    row = { "topic_id" => 8, "post_id" => nil, "url" => "/t/10", "clicks" => 1 }
    links.call(row)
    links.call(row.dup)
    links.flush
    expect(writes).to eq([row, row])
  end
end

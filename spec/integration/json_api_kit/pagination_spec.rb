# frozen_string_literal: true

require_relative "support"

RSpec.describe "a page of a listing" do
  include_context "with a listing of topics"

  let(:params) { { sort: { created_at: :asc }, page: { size: 2 } } }
  let(:query) { { "page" => { "size" => "2" } } }

  it "returns the first page and links to the next" do
    expect(document).to eq(
      data: [
        topic_object(oldest, cursor: cursor_at(0)),
        topic_object(middle, cursor: cursor_at(1)),
      ],
      included: [],
      links: links_of(next: page_url(after: cursor_at(1), size: 2)),
    )
  end

  context "when the page size holds the whole listing" do
    let(:params) { { sort: { created_at: :asc }, page: { size: 5 } } }
    let(:query) { { "page" => { "size" => "5" } } }

    it "returns every row and links to no other page" do
      expect(document).to eq(
        data: [
          topic_object(oldest, cursor: cursor_at(0)),
          topic_object(middle, cursor: cursor_at(1)),
          topic_object(newest, cursor: cursor_at(2)),
        ],
        included: [],
        links: links_of,
      )
    end
  end

  context "when the request holds no page size" do
    fab!(:replies) { 3.times.map { Fabricate(:post, topic: oldest) } }

    let(:resource) { JsonApiKitSpec::PostResource }
    let(:current) { "https://example.com/api/posts" }
    let(:params) { {} }
    let(:query) { {} }

    it "returns as many rows as the resource declares" do
      expect(document).to eq(
        data: [
          post_object(replies.first, cursor: cursor_at(0)),
          post_object(replies.second, cursor: cursor_at(1)),
        ],
        included: [],
        links: links_of(next: page_url(after: cursor_at(1))),
      )
    end
  end

  context "when the page follows the first page" do
    let(:cursor) { cursor_at(0, listing_of({ sort: { created_at: :asc }, page: { size: 1 } })) }
    let(:params) { { sort: { created_at: :asc }, page: { size: 1, after: cursor } } }
    let(:query) { { "page" => { "size" => "1", "after" => cursor } } }

    it "returns the page and links either side of it" do
      expect(document).to eq(
        data: [topic_object(middle, cursor: cursor_at(0))],
        included: [],
        links:
          links_of(
            prev: page_url(before: cursor_at(0), size: 1),
            next: page_url(after: cursor_at(0), size: 1),
          ),
      )
    end
  end
end

# frozen_string_literal: true

require_relative "support"

RSpec.describe "a document with a sparse fieldset" do
  include_context "with a listing of topics"

  let(:params) { { sort: { created_at: :asc }, page: { size: 1 }, fields: { topics: [:title] } } }

  it "renders the field of the primary type it asks for" do
    expect(document).to eq(
      data: [topic_object(oldest, fields: %w[title], cursor: cursor_at(0))],
      included: [],
      links: links_of(next: page_url(after: cursor_at(0))),
    )
  end

  context "when the request has no fieldset" do
    let(:params) { { sort: { created_at: :asc }, page: { size: 1 } } }

    it "renders every field the resource declares" do
      expect(document).to eq(
        data: [topic_object(oldest, cursor: cursor_at(0))],
        included: [],
        links: links_of(next: page_url(after: cursor_at(0))),
      )
    end
  end

  context "when the fieldset holds an unknown field" do
    let(:params) do
      { sort: { created_at: :asc }, page: { size: 1 }, fields: { topics: [:secrets] } }
    end

    it "renders no attribute" do
      expect(document).to eq(
        data: [topic_object(oldest, fields: [], cursor: cursor_at(0))],
        included: [],
        links: links_of(next: page_url(after: cursor_at(0))),
      )
    end
  end

  context "when the fieldset is on a related type" do
    let(:params) do
      {
        sort: {
          created_at: :asc,
        },
        page: {
          size: 1,
        },
        include: %w[user],
        fields: {
          users: [:username],
        },
      }
    end

    it "renders the related record with that field" do
      expect(document).to eq(
        data: [
          topic_object(
            oldest,
            cursor: cursor_at(0),
            relationships: {
              "user" =>
                relationship_object(
                  "topics",
                  oldest,
                  "user",
                  data: identifier_of("users", oldest.user),
                ),
            },
          ),
        ],
        included: [user_object(oldest.user)],
        links: links_of(next: page_url(after: cursor_at(0))),
      )
    end
  end

  context "when the fieldset of a related type is empty" do
    let(:params) do
      { sort: { created_at: :asc }, page: { size: 1 }, include: %w[user], fields: { users: [] } }
    end

    it "renders the related record with its type and its id" do
      expect(document).to eq(
        data: [
          topic_object(
            oldest,
            cursor: cursor_at(0),
            relationships: {
              "user" =>
                relationship_object(
                  "topics",
                  oldest,
                  "user",
                  data: identifier_of("users", oldest.user),
                ),
            },
          ),
        ],
        included: [user_object(oldest.user, fields: [])],
        links: links_of(next: page_url(after: cursor_at(0))),
      )
    end
  end

  context "when the fieldset leaves a relationship out" do
    let(:params) do
      {
        sort: {
          created_at: :asc,
        },
        page: {
          size: 1,
        },
        include: %w[user],
        fields: {
          topics: [:title],
        },
      }
    end

    it "renders no relationship and no related record" do
      expect(document).to eq(
        data: [topic_object(oldest, fields: %w[title], cursor: cursor_at(0))],
        included: [],
        links: links_of(next: page_url(after: cursor_at(0))),
      )
    end
  end

  context "when the fieldset holds a relationship only" do
    let(:params) { { include: %w[user], fields: { topics: %w[user] }, page: { size: 1 } } }
    let(:query) { { "include" => "user", "fields" => { "topics" => "user" } } }

    it "renders the relationship and reads the key behind it" do
      expect(document[:data].sole[:relationships].keys).to eq(%w[user])
    end
  end

  describe "the columns a narrow fieldset reads" do
    subject(:columns) do
      track_sql_queries { document }
        .grep(/FROM "topics"/)
        .flat_map { it[/\ASELECT (.+?) FROM/, 1].to_s.scan(/"topics"\."(\w+)"/) }
        .flatten
        .uniq
    end

    let(:params) { { sort: { title: :asc }, page: { size: 1 }, fields: { topics: [:title] } } }

    it "reads the column it renders and the primary key" do
      expect(columns).to contain_exactly("id", "title")
    end
  end
end

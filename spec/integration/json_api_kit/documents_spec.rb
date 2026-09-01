# frozen_string_literal: true

require_relative "support"

RSpec.describe "a rendered document" do
  include_context "with a listing of topics"

  describe "a listing" do
    let(:params) { { sort: { createdAt: :asc }, page: { size: 1 } } }
    let(:query) { { "page" => { "size" => "1" } } }

    it "renders the first page of the listing" do
      expect(document).to eq(
        data: [topic_object(oldest)],
        included: [],
        links: links_of(next: page_url(after: cursor_of_record(oldest), size: 1)),
      )
    end

    context "when all parameters are strings" do
      let(:params) do
        {
          "sort" => "createdAt",
          "include" => "user",
          "fields" => {
            "topics" => "title,user",
          },
          "page" => {
            "size" => "1",
          },
        }
      end

      it "renders the same page" do
        expect(document).to eq(
          data: [
            topic_object(
              oldest,
              fields: %w[title],
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
          links: links_of(next: page_url(after: cursor_of_record(oldest), size: 1)),
        )
      end
    end

    context "when the page holds the last row of the listing" do
      let(:params) { { sort: { createdAt: :asc }, page: { size: 5 } } }
      let(:query) { { "page" => { "size" => "5" } } }

      it "links to no page after it" do
        expect(document).to eq(
          data: [topic_object(oldest), topic_object(middle), topic_object(newest)],
          included: [],
          links: links_of,
        )
      end
    end

    context "when the page follows another page" do
      let(:params) do
        { sort: { createdAt: :asc }, page: { size: 1, after: cursor_of_record(oldest) } }
      end
      let(:query) { { "page" => { "size" => "1", "after" => cursor_of_record(oldest) } } }

      it "links to the page before it" do
        expect(document).to eq(
          data: [topic_object(middle)],
          included: [],
          links:
            links_of(
              prev: page_url(before: cursor_of_record(middle), size: 1),
              next: page_url(after: cursor_of_record(middle), size: 1),
            ),
        )
      end
    end

    context "when the listing holds no row" do
      let(:params) do
        { sort: { createdAt: :asc }, filter: { title: "No topic carries this title" } }
      end
      let(:query) { {} }

      it "renders an empty list" do
        expect(document).to eq(data: [], included: [], links: links_of)
      end
    end
  end

  describe "one record" do
    let(:current) { "https://example.com/api/topics/#{middle.id}" }

    it "renders the record" do
      expect(one_document(middle.id)).to eq(
        data: topic_object(middle),
        included: [],
        links: {
          self: self_link,
        },
      )
    end

    context "when the request asks for one field" do
      let(:params) { { fields: { topics: [:title] } } }

      it "renders that field only" do
        expect(one_document(middle.id)).to eq(
          data: topic_object(middle, fields: %w[title]),
          included: [],
          links: {
            self: self_link,
          },
        )
      end
    end

    context "when the request includes a relationship" do
      let(:params) { { include: %w[user] } }
      let(:query) { { "include" => "user" } }

      it "links to itself with the parameters of the request" do
        expect(one_document(middle.id)[:links]).to eq(self: self_link)
      end
    end

    context "when no record has that id" do
      it "renders a not found error" do
        expect(rendered_error(one_document(-1))).to eq(not_found)
      end
    end

    context "when the resource does not expose the row" do
      let(:resource) do
        Class.new(JsonApiKit::Resource) do
          model Topic
          type :topics
          scope { |guardian| Topic.where(closed: true) }
        end
      end

      it "renders a not found error" do
        expect(rendered_error(one_document(middle.id))).to eq(not_found)
      end
    end
  end

  describe "the parameters a caller sends" do
    let(:params) { { "page" => { "anchor" => { "id" => middle.id }, "size" => 1 } } }

    it "stay as they were" do
      expect { document }.not_to change { params.deep_dup }
    end
  end

  describe "the status of a document" do
    subject(:status) do
      JsonApiKit::Document::Collection.for(params, resource:, guardian:, urls:, glossary:).status
    end

    it "answers 200 for a rendered listing" do
      expect(status).to eq("200")
    end

    context "when the document holds one record" do
      subject(:status) do
        JsonApiKit::Document::Individual.for(
          middle.id,
          params,
          resource:,
          guardian:,
          urls:,
          glossary:,
        ).status
      end

      it "answers 200 for a rendered record" do
        expect(status).to eq("200")
      end
    end

    context "when no record has that id" do
      subject(:status) do
        JsonApiKit::Document::Individual.for(
          -1,
          params,
          resource:,
          guardian:,
          urls:,
          glossary:,
        ).status
      end

      it "answers 404 for a not found error" do
        expect(status).to eq("404")
      end
    end
  end
end

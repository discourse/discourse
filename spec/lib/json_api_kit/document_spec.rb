# frozen_string_literal: true

RSpec.describe JsonApiKit::Document do
  fab!(:topic) do
    Fabricate(:topic, title: "A topic a document renders", created_at: Time.utc(2026, 8, 1))
  end
  fab!(:other_topic) do
    Fabricate(:topic, title: "A topic a scope leaves out", created_at: Time.utc(2026, 8, 2))
  end

  let(:resource) do
    Class.new(JsonApiKit::Resource) do
      model Topic
      type :topics
      sort :created_at
      default_sort created_at: :asc
      attribute :title
    end
  end
  let(:guardian) { Guardian.new }
  let(:glossary) { JsonApiKit::Glossary.new([JsonApiKit::Glossary::CasingRule]) }
  let(:urls) do
    JsonApiKit::Urls.new(base: "https://example.com/api", current: "https://example.com/api/topics")
  end
  let(:parameters) { {} }

  describe "Collection.for" do
    subject(:document) do
      JsonApiKit::Document::Collection.for(
        parameters,
        resource:,
        guardian:,
        urls:,
        glossary:,
        scoped_to:,
      )
    end

    let(:scoped_to) { nil }
    let(:listed_ids) { document.to_h[:data].map { it[:id] } }

    it "renders every record of the listing" do
      expect(listed_ids).to eq([topic.id.to_s, other_topic.id.to_s])
    end

    it "returns the status of a rendered document" do
      expect(document.status).to eq("200")
    end

    context "when a caller narrows the listing with a scope" do
      let(:scoped_to) { Topic.where(id: topic.id) }

      it "renders the records that scope holds" do
        expect(listed_ids).to eq([topic.id.to_s])
      end
    end

    context "when the contract refuses the request" do
      let(:parameters) { { sort: { secrets: :asc } } }

      it { is_expected.to be_a(JsonApiKit::Document::Errors) }

      it "renders the error as a document" do
        expect(document.to_h[:errors].sole).to include(status: "400", title: "No such sort")
      end
    end
  end

  describe "Individual.for" do
    subject(:document) do
      JsonApiKit::Document::Individual.for(id, parameters, resource:, guardian:, urls:, glossary:)
    end

    let(:id) { topic.id }

    it "renders the record as a document" do
      expect(document.to_h[:data][:id]).to eq(topic.id.to_s)
    end

    context "when no row holds that id" do
      let(:id) { -1 }

      it { is_expected.to be_a(JsonApiKit::Document::Errors) }

      it "renders the error as a document" do
        expect(document.to_h[:errors].sole).to include(status: "404", title: "No such record")
      end
    end
  end
end

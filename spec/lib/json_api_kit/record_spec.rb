# frozen_string_literal: true

RSpec.describe JsonApiKit::Record do
  subject(:record) { described_class.new(row, resource.fields, type: "topics", relationships:) }

  fab!(:author, :user)
  fab!(:topic) { Fabricate(:topic, user: author, title: "A row read as a record") }

  let(:resource) do
    Class.new(JsonApiKit::Resource) do
      model Topic
      type :topics
      attribute :title
    end
  end
  let(:users_resource) do
    Class.new(JsonApiKit::Resource) do
      model User
      type :users
      attribute :username
    end
  end
  let(:row) { JsonApiKit::Pagination::Row.new(record: topic, segment: nil) }
  let(:author_record) do
    described_class.new(
      JsonApiKit::Pagination::Row.new(record: author, segment: nil),
      users_resource.fields,
      type: "users",
    )
  end
  let(:relationships) { {} }

  describe "#attributes" do
    it "renders the fields that the resource declares" do
      expect(record.attributes).to eq("title" => topic.title)
    end
  end

  describe "#id" do
    it "returns the id as a string" do
      expect(record.id).to eq(topic.id.to_s)
    end
  end

  describe "#identity" do
    it "returns the type and the id" do
      expect(record.identity).to eq(
        JsonApiKit::Record::Identity.new(type: "topics", id: topic.id.to_s),
      )
    end

    it "matches another reading of the same row" do
      expect(record.identity).to eq(
        described_class.new(row, resource.fields(["secrets"]), type: "topics").identity,
      )
    end
  end

  describe "#merge" do
    subject(:merged) { record.merge(other) }

    let(:relationships) { { "user" => JsonApiKit::Linkage::ToOne.new([author_record]) } }
    let(:other) do
      described_class.new(row, resource.fields(["secrets"]), type: "topics", relationships: editors)
    end
    let(:editors) do
      {
        "editors" =>
          JsonApiKit::Linkage::ToMany.new(JsonApiKit::Records.new([author_record]).page(1)),
      }
    end

    it "holds the relationships of both readings" do
      expect(merged.relationships.keys).to contain_exactly("user", "editors")
    end

    it "renders its own fields" do
      expect(merged.attributes).to eq("title" => topic.title)
    end

    it "leaves this record unchanged" do
      expect { merged }.not_to change { record.relationships }
    end

    context "when both readings hold the same relationship" do
      let(:editors) { { "user" => JsonApiKit::Linkage::ToOne.new([]) } }

      it "keeps its own relationship" do
        expect(merged.relationships["user"].collapse { it.id }).to eq(author.id.to_s)
      end
    end
  end

  describe "#related_records" do
    it "returns none where the record relates to nothing" do
      expect(record.related_records).to be_empty
    end

    context "when the record holds one relationship" do
      let(:relationships) { { "user" => JsonApiKit::Linkage::ToOne.new([author_record]) } }

      it "returns the records under it" do
        expect(record.related_records).to eq([author_record])
      end
    end

    context "when the record holds several relationships" do
      let(:relationships) do
        {
          "user" => JsonApiKit::Linkage::ToOne.new([author_record]),
          "editors" =>
            JsonApiKit::Linkage::ToMany.new(JsonApiKit::Records.new([author_record]).page(1)),
        }
      end

      it "returns the records under all of them" do
        expect(record.related_records).to eq([author_record, author_record])
      end
    end
  end
end

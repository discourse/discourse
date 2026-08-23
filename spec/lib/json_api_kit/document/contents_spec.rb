# frozen_string_literal: true

RSpec.describe JsonApiKit::Document::Contents do
  subject(:contents) { described_class.new(records, related_records) }

  fab!(:author, :user)
  fab!(:group) { Fabricate(:group, name: "the_authors_group") }
  fab!(:topic) { Fabricate(:topic, user: author, title: "A topic a document renders") }
  fab!(:other_topic) { Fabricate(:topic, title: "A second topic a document renders") }

  let(:author_record) { record_of(author, "users") }
  let(:other_topic_record) { record_of(other_topic, "topics") }
  let(:records) { [record_of(topic, "topics", "user" => linkage(author_record))] }
  let(:related_records) { [author_record] }

  let(:guardian) { Guardian.new }

  def record_of(model, type, relationships = {})
    JsonApiKit::Record.new(
      JsonApiKit::Pagination::Row.new(record: model, segment: nil),
      JsonApiKit::Declarations::Fields.for(
        nil,
        guardian:,
        attributes: [],
        relationships: [],
        schema: JsonApiKit::Schema.new(model.class),
      ),
      type:,
      relationships:,
    )
  end

  def linkage(*records) = JsonApiKit::Linkage.new(records)

  describe "#primary" do
    it "returns the records a caller asks for" do
      expect(contents.primary.map(&:record)).to eq([topic])
    end

    context "when a path reads a primary record a second time" do
      let(:related_records) { [author_record, record_of(topic, "topics", "tags" => linkage)] }

      it "holds the relationships of both readings" do
        expect(contents.primary.first.relationships.keys).to contain_exactly("user", "tags")
      end
    end

    context "when a caller asks for more than one record" do
      let(:records) { [*super(), other_topic_record] }

      it "keeps the order a caller asks for" do
        expect(contents.primary.map(&:record)).to eq([topic, other_topic])
      end
    end
  end

  describe "#related" do
    it "returns the records the data relates to" do
      expect(contents.related.map(&:record)).to eq([author])
    end

    context "when a path reads a primary record a second time" do
      let(:related_records) { [author_record, record_of(topic, "topics")] }

      it "drops that record" do
        expect(contents.related.map(&:record)).to eq([author])
      end
    end

    context "when a caller asks for more than one record" do
      let(:records) { [*super(), other_topic_record] }

      it "leaves out every record a caller asks for" do
        expect(contents.related.map(&:record)).to eq([author])
      end
    end

    context "when a caller asks for no record" do
      let(:records) { [] }
      let(:related_records) { [author_record, other_topic_record] }

      it "returns every record" do
        expect(contents.related.map(&:record)).to eq([author, other_topic])
      end
    end

    context "when two paths read one record" do
      let(:related_records) do
        [author_record, record_of(author, "users", "groups" => linkage(record_of(group, "groups")))]
      end

      it "returns it one time" do
        expect(contents.related.map(&:record)).to eq([author])
      end

      it "holds the relationships of both readings" do
        expect(contents.related.first.relationships.keys).to contain_exactly("groups")
      end
    end
  end
end

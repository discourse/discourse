# frozen_string_literal: true

RSpec.describe JsonApiKit::Included do
  subject(:included) { described_class.for(records) }

  fab!(:author, :user)
  fab!(:group) { Fabricate(:group, name: "the_authors_group") }
  fab!(:topic) { Fabricate(:topic, user: author, title: "A topic that holds relations") }
  fab!(:another) { Fabricate(:topic, user: author, title: "Another topic by that author") }

  let(:author_record) { record_of(author, "users") }
  let(:records) { [record_of(topic, "topics", "user" => linkage(author_record))] }

  def record_of(model, type, relationships = {})
    JsonApiKit::Record.new(
      JsonApiKit::Pagination::Row.new(record: model, segment: nil),
      JsonApiKit::Declarations::Fields.for(
        nil,
        attributes: [],
        relationships: [],
        schema: JsonApiKit::Schema.new(model.class),
      ),
      type:,
      relationships:,
    )
  end

  def linkage(*records) = JsonApiKit::Linkage.new(records)

  it "holds the records that these records relate to" do
    expect(included.map(&:record)).to eq([author])
  end

  context "when nothing relates to anything" do
    let(:records) { [record_of(topic, "topics")] }

    it "holds nothing" do
      expect(included).to be_empty
    end
  end

  context "when two records relate to one record" do
    let(:records) do
      [
        record_of(topic, "topics", "user" => linkage(author_record)),
        record_of(another, "topics", "user" => linkage(record_of(author, "users"))),
      ]
    end

    it "holds it for each of them" do
      expect(included.map(&:record)).to eq([author, author])
    end
  end

  context "when two records share a type and nothing else" do
    let(:records) do
      [record_of(topic, "topics", "user" => linkage(author_record, record_of(hidden, "users")))]
    end

    fab!(:hidden, :user)

    it "holds each of them" do
      expect(included.map(&:record)).to eq([author, hidden])
    end
  end

  context "when a related record relates to another one" do
    let(:author_record) do
      record_of(author, "users", "groups" => linkage(record_of(group, "groups")))
    end

    it "holds the records past the first" do
      expect(included.map(&:record)).to eq([author, group])
    end
  end
end

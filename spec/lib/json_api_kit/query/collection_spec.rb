# frozen_string_literal: true

RSpec.describe JsonApiKit::Query::Collection do
  subject(:query) { described_class.new(resource, request, scoped_to:) }

  fab!(:first_topic) do
    Fabricate(:topic, title: "Segments of a listing", created_at: Time.utc(2026, 8, 1))
  end
  fab!(:second_topic) do
    Fabricate(:topic, title: "Cursors and their values", created_at: Time.utc(2026, 8, 2))
  end
  fab!(:third_topic) do
    Fabricate(:topic, title: "Bands read one at a time", created_at: Time.utc(2026, 8, 3))
  end

  let(:resource) do
    Class.new(JsonApiKit::Resource) do
      model Topic
      type :topics
      sort :created_at
      default_sort created_at: :asc
    end
  end
  let(:request) { JsonApiKit::Request::Collection.new(params, guardian:) }
  let(:params) { {} }
  let(:guardian) { Guardian.new }
  let(:scoped_to) { nil }

  def request_for(params) = JsonApiKit::Request::Collection.new(params, guardian: Guardian.new)

  describe ".new" do
    let(:params) { { sort: { secrets: :asc } } }

    it "reads nothing before a caller asks for records" do
      expect { query }.not_to raise_error
    end
  end

  describe "#rows" do
    subject(:rows) { query.rows }

    it "gives every row of the page a cursor" do
      expect(rows.map(&:cursor)).to all(be_present)
    end
  end

  describe "#next" do
    subject(:next_cursor) { query.next }

    let(:params) { { page: { size: 2 } } }

    it "returns the cursor that starts the next page" do
      expect(
        described_class
          .new(resource, request_for(page: { after: next_cursor }))
          .records
          .map(&:record),
      ).to eq([third_topic])
    end

    context "when the page holds the last row of the listing" do
      let(:params) { { page: { size: 5 } } }

      it "returns nothing" do
        expect(next_cursor).to be_nil
      end
    end
  end

  describe "#pages" do
    subject(:pages) { query.pages }

    let(:params) { { page: { size: 2 } } }

    it "returns the cursor at each end" do
      expect(pages).to eq(before: query.previous, after: query.next)
    end
  end

  describe "#previous" do
    subject(:previous_cursor) { query.previous }

    let(:params) { { page: { size: 2 } } }

    it "returns nothing" do
      expect(previous_cursor).to be_nil
    end

    context "when a caller reads from further into the listing" do
      let(:first_cursor) { described_class.new(resource, request_for({})).rows.first.cursor.to_s }
      let(:params) { { page: { size: 2, after: first_cursor } } }

      it "returns the cursor that reads the page before it" do
        expect(previous_cursor).to be_present
      end
    end
  end

  describe "the fields it renders" do
    subject(:fields) { query.records.map(&:attributes) }

    let(:resource) do
      Class.new(JsonApiKit::Resource) do
        model Topic
        type :topics
        sort :created_at
        default_sort created_at: :asc
        attribute :title
        attribute :closed
      end
    end

    it "renders every row in the order the listing reads them" do
      expect(fields.map { it["title"] }).to eq(
        [first_topic.title, second_topic.title, third_topic.title],
      )
    end

    context "when the fields hold a column attribute" do
      let(:params) { { fields: { topics: [:title] } } }

      it "renders only those fields" do
        expect(fields.first.keys).to contain_exactly("title")
      end

      it "reads only the columns those fields and the order need" do
        expect(query.records.first.record.attributes.keys).to contain_exactly(
          "id",
          "title",
          "created_at",
        )
      end
    end

    context "when the fields hold a block attribute" do
      let(:resource) do
        Class.new(JsonApiKit::Resource) do
          model Topic
          type :topics
          sort :created_at
          default_sort created_at: :asc
          attribute :title
          attribute(:slug) { |record| record.title.parameterize }
        end
      end
      let(:params) { { fields: { topics: %i[title slug] } } }

      it "reads the whole row" do
        expect(query.records.first.record.attributes.keys).to include("closed", "views")
      end
    end
  end

  describe "#records" do
    subject(:records) { query.records.map(&:record) }

    it "reads the rows the resource exposes in the order it declares" do
      expect(records).to eq([first_topic, second_topic, third_topic])
    end

    context "when the sort holds a key" do
      let(:params) { { sort: { created_at: :desc } } }

      it "reads the rows that way" do
        expect(records).to eq([third_topic, second_topic, first_topic])
      end
    end

    context "when the resource is read as part of another listing" do
      let(:scoped_to) { Topic.where(id: [first_topic.id, third_topic.id]) }

      it "reads only the rows both allow" do
        expect(records).to eq([first_topic, third_topic])
      end
    end

    context "when the page holds a size" do
      let(:params) { { page: { size: 2 } } }

      it "reads only that many rows" do
        expect(records).to eq([first_topic, second_topic])
      end
    end

    context "when the filter holds a value" do
      let(:resource) { Class.new(super()) { filter :title } }
      let(:params) { { filter: { title: second_topic.title } } }

      it "reads only the rows that filter keeps" do
        expect(records).to eq([second_topic])
      end
    end

    context "when the resource declares a scope" do
      let(:resource) do
        Class.new(super()) { scope { |guardian| Topic.where(user_id: guardian.user&.id) } }
      end
      let(:guardian) { Guardian.new(second_topic.user) }

      it "reads only the rows that scope exposes" do
        expect(records).to eq([second_topic])
      end
    end
  end
end

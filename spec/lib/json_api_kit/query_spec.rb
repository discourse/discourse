# frozen_string_literal: true

RSpec.describe JsonApiKit::Query do
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
      sort :created_at
      default_sort created_at: :asc
    end
  end
  let(:request) { JsonApiKit::Request.new(params, guardian:) }
  let(:params) { {} }
  let(:guardian) { Guardian.new }
  let(:scoped_to) { nil }

  def request_for(asked) = JsonApiKit::Request.new(asked, guardian: Guardian.new)

  describe ".new" do
    let(:params) { { sort: { secrets: :asc } } }

    it "reads nothing until it is asked for records" do
      expect { query }.not_to raise_error
    end
  end

  describe "#rows" do
    subject(:rows) { query.rows }

    it "is every row of the page, each one a place the listing reads on from" do
      expect(rows.map(&:cursor)).to all(be_present)
    end
  end

  describe "#next" do
    subject(:following) { query.next }

    let(:params) { { page: { size: 2 } } }

    it "names the page the listing carries on with" do
      expect(described_class.new(resource, request_for(page: { after: following })).records).to eq(
        [third_topic],
      )
    end

    context "when the page holds the last row of the listing" do
      let(:params) { { page: { size: 5 } } }

      it "names no page after it" do
        expect(following).to be_nil
      end
    end
  end

  describe "#previous" do
    subject(:preceding) { query.previous }

    let(:params) { { page: { size: 2 } } }

    it "names nothing behind a page read from the start of a listing" do
      expect(preceding).to be_nil
    end

    context "with a page read from further in" do
      let(:first_cursor) { described_class.new(resource, request_for({})).rows.first.cursor.to_s }
      let(:params) { { page: { size: 2, after: first_cursor } } }

      it "names the page it was read on from" do
        expect(preceding).to be_present
      end
    end
  end

  describe "#records" do
    subject(:records) { query.records }

    it "reads the rows the resource exposes, ordered the way it declares" do
      expect(records).to eq([first_topic, second_topic, third_topic])
    end

    context "with an order asked for" do
      let(:params) { { sort: { created_at: :desc } } }

      it "reads them that way instead" do
        expect(records).to eq([third_topic, second_topic, first_topic])
      end
    end

    context "when the resource is read as part of another listing" do
      let(:scoped_to) { Topic.where(id: [first_topic.id, third_topic.id]) }

      it "reads only the rows both allow" do
        expect(records).to eq([first_topic, third_topic])
      end
    end

    context "with a page size asked for" do
      let(:params) { { page: { size: 2 } } }

      it "reads only that many rows" do
        expect(records).to eq([first_topic, second_topic])
      end
    end

    context "with a page larger than the resource allows" do
      let(:params) { { page: { size: 500 } } }

      it "refuses to read it" do
        expect { records }.to raise_error(JsonApiKit::Declarations::PageLimits::TooLarge)
      end
    end

    context "with a filter asked for" do
      let(:resource) { Class.new(super()) { filter :title } }
      let(:params) { { filter: { title: second_topic.title } } }

      it "reads only the rows that filter keeps" do
        expect(records).to eq([second_topic])
      end
    end

    context "with a scope the resource declares" do
      let(:resource) do
        Class.new(super()) { scope { |guardian| Topic.where(user_id: guardian.user&.id) } }
      end
      let(:guardian) { Guardian.new(second_topic.user) }

      it "reads only the rows that scope exposes to whoever is asking" do
        expect(records).to eq([second_topic])
      end
    end
  end
end

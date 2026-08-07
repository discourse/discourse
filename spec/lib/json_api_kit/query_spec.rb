# frozen_string_literal: true

RSpec.describe JsonApiKit::Query do
  subject(:query) { described_class.new(resource, params, guardian:, scoped_to:) }

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
  let(:params) { {} }
  let(:guardian) { Guardian.new }
  let(:scoped_to) { nil }

  describe ".new" do
    let(:params) { { sort: { secrets: :asc } } }

    it "reads nothing until it is asked for records" do
      expect { query }.not_to raise_error
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

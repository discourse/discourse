# frozen_string_literal: true

RSpec.describe JsonApiKit::Pagination::Around do
  subject(:page) { described_class.new(scope, order:, row:, before:, after:, include_row:) }

  fab!(:first_topic, :topic)
  fab!(:second_topic, :topic)
  fab!(:third_topic, :topic)
  fab!(:fourth_topic, :topic)
  fab!(:fifth_topic, :topic)

  let(:model) { Topic }
  let(:topics) { [first_topic, second_topic, third_topic, fourth_topic, fifth_topic] }
  let(:order) do
    JsonApiKit::Pagination::Order.for(
      JsonApiKit::Pagination::Keyset.new([JsonApiKit::Pagination::Keyset::Key.new(:id, model:)]),
    )
  end
  let(:scope) { Topic.where(id: topics.map(&:id)) }
  let(:anchored) { third_topic }
  let(:row) { order.locate(scope, matching: ->(rows) { rows.where(id: anchored.id) }) }
  let(:second_cursor) { order.first.position_of(second_topic).to_cursor }
  let(:third_cursor) { order.first.position_of(third_topic).to_cursor }
  let(:fourth_cursor) { order.first.position_of(fourth_topic).to_cursor }
  let(:before) { 1 }
  let(:after) { 1 }
  let(:include_row) { true }

  describe "#records" do
    subject(:records) { page.records }

    it "reads the rows either side of the anchor, with the anchor between them" do
      expect(records).to eq([second_topic, third_topic, fourth_topic])
    end

    context "without the anchor row itself" do
      let(:include_row) { false }

      it "keeps its neighbours and leaves it out" do
        expect(records).to eq([second_topic, fourth_topic])
      end
    end

    context "with rows asked for on one side only" do
      let(:before) { 0 }

      it "reads only that way" do
        expect(records).to eq([third_topic, fourth_topic])
      end
    end

    context "with more rows asked for than the listing holds" do
      let(:before) { 10 }
      let(:after) { 10 }

      it "reads as far as the listing goes, either way" do
        expect(records).to eq(topics)
      end
    end
  end

  describe "#rows" do
    it "hands back the very row it was anchored on" do
      expect(page.rows[1]).to be(row)
    end
  end

  describe "#next" do
    subject(:next_page) { page.next }

    it "points at the last row read after the anchor" do
      expect(next_page).to eq(fourth_cursor)
    end

    context "when the anchor is the last row of the listing" do
      let(:anchored) { fifth_topic }

      it "has nowhere to point" do
        expect(next_page).to be_nil
      end
    end

    context "with no rows asked for after the anchor" do
      let(:after) { 0 }

      it "points at the anchor, which is where reading on begins" do
        expect(next_page).to eq(third_cursor)
      end
    end
  end

  describe "#previous" do
    subject(:previous_page) { page.previous }

    it "points at the first row read before the anchor" do
      expect(previous_page).to eq(second_cursor)
    end

    context "when the anchor is the first row of the listing" do
      let(:anchored) { first_topic }

      it "has nowhere to point" do
        expect(previous_page).to be_nil
      end
    end
  end
end

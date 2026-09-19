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
    JsonApiKit::Pagination::Order.new(
      JsonApiKit::Pagination::Keyset.new([JsonApiKit::Pagination::Keyset::Key.new(:id, model:)]),
    )
  end
  let(:scope) { Topic.where(id: topics.map(&:id)) }
  let(:anchor_topic) { third_topic }
  let(:row) { order.locate(scope.where(id: anchor_topic.id)) }
  let(:second_cursor) { order.first.position_of(second_topic).to_cursor }
  let(:third_cursor) { order.first.position_of(third_topic).to_cursor }
  let(:fourth_cursor) { order.first.position_of(fourth_topic).to_cursor }
  let(:before) { 1 }
  let(:after) { 1 }
  let(:include_row) { true }

  describe "#rows" do
    subject(:records) { page.rows.map(&:record) }

    it "reads the rows around the anchor in the order of the listing" do
      expect(records).to eq([second_topic, third_topic, fourth_topic])
    end

    it "puts the anchor row itself between the two pages" do
      expect(page.rows[1]).to be(row)
    end

    context "when the caller leaves the anchor row out" do
      let(:include_row) { false }

      it "leaves the anchor row out of the page" do
        expect(records).to eq([second_topic, fourth_topic])
      end
    end

    context "when the caller asks for no row before the anchor" do
      let(:before) { 0 }

      it "reads only the rows after the anchor" do
        expect(records).to eq([third_topic, fourth_topic])
      end
    end

    context "when the caller asks for more rows than the listing holds" do
      let(:before) { 10 }
      let(:after) { 10 }

      it "reads every row of the listing" do
        expect(records).to eq(topics)
      end
    end
  end

  describe "#next" do
    subject(:next_page) { page.next }

    it "returns the cursor of the last row after the anchor" do
      expect(next_page).to eq(fourth_cursor)
    end

    context "when the anchor is the last row of the listing" do
      let(:anchor_topic) { fifth_topic }

      it "returns no cursor" do
        expect(next_page).to be_nil
      end
    end

    context "when the caller asks for no row after the anchor" do
      let(:after) { 0 }

      it "returns the cursor of the anchor row" do
        expect(next_page).to eq(third_cursor)
      end
    end
  end

  describe "#previous" do
    subject(:previous_page) { page.previous }

    it "returns the cursor of the first row before the anchor" do
      expect(previous_page).to eq(second_cursor)
    end

    context "when the anchor is the first row of the listing" do
      let(:anchor_topic) { first_topic }

      it "returns no cursor" do
        expect(previous_page).to be_nil
      end
    end
  end
end

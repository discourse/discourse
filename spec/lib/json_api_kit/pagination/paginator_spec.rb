# frozen_string_literal: true

RSpec.describe JsonApiKit::Pagination::Paginator do
  subject(:paginator) { described_class.for(scope, order:, size:, after:, before:) }

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
  let(:first_cursor) { order.first.position_of(first_topic).to_cursor }
  let(:second_cursor) { order.first.position_of(second_topic).to_cursor }
  let(:third_cursor) { order.first.position_of(third_topic).to_cursor }
  let(:fourth_cursor) { order.first.position_of(fourth_topic).to_cursor }
  let(:fifth_cursor) { order.first.position_of(fifth_topic).to_cursor }
  let(:size) { 2 }
  let(:after) { nil }
  let(:before) { nil }

  describe ".for" do
    it "returns a paginator that reads forwards" do
      expect(paginator).to be_an_instance_of(described_class::Forwards)
    end

    context "when there is an after cursor" do
      let(:after) { second_cursor }

      it "returns a paginator that reads forwards from it" do
        expect(paginator).to be_an_instance_of(described_class::Forwards)
      end
    end

    context "when there is a before cursor" do
      let(:before) { fourth_cursor }

      it "returns a paginator that reads backwards from it" do
        expect(paginator).to be_an_instance_of(described_class::Backwards)
      end
    end

    context "when there is a cursor at both ends" do
      let(:after) { first_cursor }
      let(:before) { fourth_cursor }

      it "refuses the request" do
        expect { paginator }.to raise_error(ArgumentError)
      end
    end
  end

  describe "#rows" do
    subject(:rows) { paginator.rows }

    it "reads the first rows of the listing" do
      expect(rows.map(&:record)).to eq([first_topic, second_topic])
    end

    context "when there is a before cursor" do
      let(:before) { fifth_cursor }

      it "reads the page before it, in the order of the listing" do
        expect(rows.map(&:record)).to eq([third_topic, fourth_topic])
      end
    end
  end

  describe "#next" do
    subject(:next_page) { paginator.next }

    it "returns the cursor of the last row of the page" do
      expect(next_page).to eq(second_cursor)
    end

    context "when the page ends on the last row of the listing" do
      let(:after) { third_cursor }

      it "returns no cursor" do
        expect(next_page).to be_nil
      end
    end

    context "when the cursor sits on the last row" do
      let(:after) { fifth_cursor }

      it "returns no cursor" do
        expect(next_page).to be_nil
      end
    end

    context "when the page reads backwards" do
      let(:before) { fifth_cursor }

      it "returns the cursor of the last row of the page" do
        expect(next_page).to eq(fourth_cursor)
      end
    end

    context "when the page reads backwards past the first row of the listing" do
      let(:before) { first_cursor }

      it "returns the cursor it starts from" do
        expect(next_page).to eq(first_cursor)
      end
    end
  end

  describe "#previous" do
    subject(:previous_page) { paginator.previous }

    it "returns no cursor" do
      expect(previous_page).to be_nil
    end

    context "when there is an after cursor" do
      let(:after) { second_cursor }

      it "returns the cursor of the first row of the page" do
        expect(previous_page).to eq(third_cursor)
      end
    end

    context "when the cursor sits on the last row" do
      let(:after) { fifth_cursor }

      it "returns the cursor it starts from" do
        expect(previous_page).to eq(fifth_cursor)
      end
    end

    context "when the page reads backwards" do
      let(:before) { fifth_cursor }

      it "returns the cursor of the first row of the page" do
        expect(previous_page).to eq(third_cursor)
      end
    end

    context "when the page reads backwards to the first row of the listing" do
      let(:before) { third_cursor }

      it "returns no cursor" do
        expect(previous_page).to be_nil
      end
    end
  end
end

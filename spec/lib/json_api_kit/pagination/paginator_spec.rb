# frozen_string_literal: true

RSpec.describe JsonApiKit::Pagination::Paginator do
  subject(:paginator) { described_class.for(scope, keyset:, size:, after:, before:) }

  fab!(:first_topic, :topic)
  fab!(:second_topic, :topic)
  fab!(:third_topic, :topic)
  fab!(:fourth_topic, :topic)
  fab!(:fifth_topic, :topic)

  let(:model) { Topic }
  let(:topics) { [first_topic, second_topic, third_topic, fourth_topic, fifth_topic] }
  let(:keyset) do
    JsonApiKit::Pagination::Keyset.new([JsonApiKit::Pagination::Keyset::Key.new(:id, model:)])
  end
  let(:scope) { Topic.where(id: topics.map(&:id)) }
  let(:size) { 2 }
  let(:after) { nil }
  let(:before) { nil }

  describe ".for" do
    it "reads forwards when no end is named" do
      expect(paginator).to be_an_instance_of(described_class::Forwards)
    end

    context "with a cursor to read after" do
      let(:after) { keyset.cursor_for(second_topic) }

      it "reads forwards from it" do
        expect(paginator).to be_an_instance_of(described_class::Forwards)
      end
    end

    context "with a cursor to read before" do
      let(:before) { keyset.cursor_for(fourth_topic) }

      it "reads backwards from it" do
        expect(paginator).to be_an_instance_of(described_class::Backwards)
      end
    end

    context "with a cursor at both ends" do
      let(:after) { keyset.cursor_for(first_topic) }
      let(:before) { keyset.cursor_for(fourth_topic) }

      it "refuses to read a range" do
        expect { paginator }.to raise_error(ArgumentError)
      end
    end
  end

  describe "#records" do
    subject(:records) { paginator.records }

    it "reads the first page of the order" do
      expect(records).to eq([first_topic, second_topic])
    end

    context "with a cursor to read after" do
      let(:after) { keyset.cursor_for(second_topic) }

      it "reads the page following it" do
        expect(records).to eq([third_topic, fourth_topic])
      end
    end

    context "with a cursor to read before" do
      let(:before) { keyset.cursor_for(fifth_topic) }

      it "reads the page preceding it, in the order it is presented" do
        expect(records).to eq([third_topic, fourth_topic])
      end
    end

    context "with a cursor past the end of the order" do
      let(:after) { keyset.cursor_for(fifth_topic) }

      it "reads nothing" do
        expect(records).to be_empty
      end
    end
  end

  describe "#next" do
    subject(:next_page) { paginator.next }

    it "points at the last row of the page, for the client to read on from" do
      expect(next_page).to eq(keyset.cursor_for(second_topic))
    end

    context "with a page that reaches the end of the order" do
      let(:after) { keyset.cursor_for(third_topic) }

      it "has nowhere to point" do
        expect(next_page).to be_nil
      end
    end

    context "with a cursor past the end of the order" do
      let(:after) { keyset.cursor_for(fifth_topic) }

      it "has nowhere to point either" do
        expect(next_page).to be_nil
      end
    end

    context "when reading backwards" do
      let(:before) { keyset.cursor_for(fifth_topic) }

      it "points back at the row the page ends on" do
        expect(next_page).to eq(keyset.cursor_for(fourth_topic))
      end
    end

    context "when reading backwards past the start of the order" do
      let(:before) { keyset.cursor_for(first_topic) }

      it "points at the cursor the empty page was read from, so a client can leave it" do
        expect(next_page).to eq(keyset.cursor_for(first_topic))
      end
    end
  end

  describe "#previous" do
    subject(:previous_page) { paginator.previous }

    it "has nowhere to point from the first page" do
      expect(previous_page).to be_nil
    end

    context "with a cursor to read after" do
      let(:after) { keyset.cursor_for(second_topic) }

      it "points at the first row of the page, for the client to read back from" do
        expect(previous_page).to eq(keyset.cursor_for(third_topic))
      end
    end

    context "with a cursor past the end of the order" do
      let(:after) { keyset.cursor_for(fifth_topic) }

      it "points at the cursor the empty page was read from, so a client can leave it" do
        expect(previous_page).to eq(keyset.cursor_for(fifth_topic))
      end
    end

    context "when reading backwards" do
      let(:before) { keyset.cursor_for(fifth_topic) }

      it "points at the row the page starts on" do
        expect(previous_page).to eq(keyset.cursor_for(third_topic))
      end
    end

    context "when reading backwards to the start of the order" do
      let(:before) { keyset.cursor_for(third_topic) }

      it "has nowhere to point" do
        expect(previous_page).to be_nil
      end
    end
  end
end

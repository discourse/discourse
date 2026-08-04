# frozen_string_literal: true

RSpec.describe JsonApiKit::Pagination::Window do
  subject(:window) { described_class.new(scope, keyset:, size:, after:) }

  fab!(:first_topic, :topic)
  fab!(:second_topic, :topic)
  fab!(:third_topic, :topic)

  let(:model) { Topic }
  let(:keys) { [JsonApiKit::Pagination::Keyset::Key.new(:id, model:)] }
  let(:keyset) { JsonApiKit::Pagination::Keyset.new(keys) }
  let(:scope) { Topic.where(id: [first_topic.id, second_topic.id, third_topic.id]) }
  let(:size) { 2 }
  let(:after) { nil }

  describe "#records" do
    subject(:records) { window.records }

    it "reads the first rows of the order" do
      expect(records).to eq([first_topic, second_topic])
    end

    it "never hands back more than the page asked for" do
      expect(records.size).to eq(size)
    end

    context "with a cursor" do
      let(:after) { keyset.cursor_for(first_topic) }

      it "starts strictly after the row the cursor names" do
        expect(records).to eq([second_topic, third_topic])
      end
    end

    context "with a cursor on the last row of the order" do
      let(:after) { keyset.cursor_for(third_topic) }

      it "reads nothing" do
        expect(records).to be_empty
      end
    end

    context "when the order sorts nulls last" do
      fab!(:pinned) { Fabricate(:topic, pinned_at: Time.utc(2026, 8, 1)) }

      let(:keys) do
        [
          JsonApiKit::Pagination::Keyset::Key.new(
            :pinned_at,
            model:,
            direction: :desc,
            nulls_last: true,
          ),
          JsonApiKit::Pagination::Keyset::Key.new(:id, model:),
        ]
      end
      let(:scope) { Topic.where(id: [pinned.id, first_topic.id, second_topic.id, third_topic.id]) }
      let(:size) { 3 }

      it "reads the rows that have a value before the null tail" do
        expect(window.records).to eq([pinned, first_topic, second_topic])
      end
    end

    context "when the order is walked backwards" do
      let(:keyset) { JsonApiKit::Pagination::Keyset.new(keys).reverse }

      it "reads the last rows of the order, in the order it was walked" do
        expect(records).to eq([third_topic, second_topic])
      end
    end

    context "without a page to read, as a probe" do
      let(:size) { 0 }

      it "reads nothing" do
        expect(records).to be_empty
      end
    end
  end

  describe "#first_cursor" do
    subject(:first_cursor) { window.first_cursor }

    it "names the row the window starts on" do
      expect(first_cursor).to eq(keyset.cursor_for(first_topic))
    end

    context "with a cursor on the last row of the order" do
      let(:after) { keyset.cursor_for(third_topic) }

      it "names nothing, the window having read nothing" do
        expect(first_cursor).to be_nil
      end
    end
  end

  describe "#last_cursor" do
    subject(:last_cursor) { window.last_cursor }

    it "names the row the window ends on" do
      expect(last_cursor).to eq(keyset.cursor_for(second_topic))
    end

    context "with a cursor on the last row of the order" do
      let(:after) { keyset.cursor_for(third_topic) }

      it "names nothing, the window having read nothing" do
        expect(last_cursor).to be_nil
      end
    end
  end

  describe "#truncated?" do
    it "knows a row follows the page" do
      expect(window).to be_truncated
    end

    context "when the page reaches the end of the order" do
      let(:size) { 3 }

      it "knows nothing follows it" do
        expect(window).not_to be_truncated
      end
    end

    context "with a cursor on the last row of the order" do
      let(:after) { keyset.cursor_for(third_topic) }

      it "knows nothing follows an empty page either" do
        expect(window).not_to be_truncated
      end
    end

    context "without a page to read, as a probe" do
      let(:size) { 0 }
      let(:after) { keyset.cursor_for(second_topic) }

      it "still answers whether anything lies that way" do
        expect(window).to be_truncated
      end

      context "when nothing lies that way" do
        let(:after) { keyset.cursor_for(third_topic) }

        it "says so" do
          expect(window).not_to be_truncated
        end
      end
    end
  end
end

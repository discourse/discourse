# frozen_string_literal: true

RSpec.describe JsonApiKit::Pagination::Predicate do
  subject(:predicate) { described_class.new(keyset, cursor) }

  let(:model) { Topic }
  let(:keys) do
    [
      JsonApiKit::Pagination::Keyset::Key.new(:created_at, model:, direction: :desc),
      JsonApiKit::Pagination::Keyset::Key.new(:id, model:),
    ]
  end
  let(:keyset) { JsonApiKit::Pagination::Keyset.new(keys) }
  let(:record) { Topic.new(id: 12, created_at: Time.utc(2026, 8, 3, 12, 0, 0, 123_456)) }
  let(:cursor) { keyset.cursor_for(record) }

  describe ".new" do
    context "when the cursor holds fewer values than the order has keys" do
      let(:cursor) { JsonApiKit::Pagination::Cursor.new([12]) }

      it "refuses a cursor minted for another order" do
        expect { predicate }.to raise_error(JsonApiKit::Pagination::Cursor::Invalid)
      end
    end

    context "when the cursor holds more values than the order has keys" do
      let(:cursor) { JsonApiKit::Pagination::Cursor.new([1, 2, 3]) }

      it "refuses it rather than silently comparing the first ones" do
        expect { predicate }.to raise_error(JsonApiKit::Pagination::Cursor::Invalid)
      end
    end
  end

  describe "#sql" do
    subject(:sql) { predicate.sql }

    it "asks for the rows after the cursor, hinting at the leading key" do
      expect(sql).to eq(
        '"topics"."created_at" <= :created_at AND ' \
          '(("topics"."created_at" = :created_at AND "topics"."id" > :id) ' \
          'OR ("topics"."created_at" < :created_at))',
      )
    end

    context "with a single key" do
      let(:keys) { [JsonApiKit::Pagination::Keyset::Key.new(:id, model:)] }
      let(:record) { Topic.new(id: 12) }

      it "needs no hint to reach its index" do
        expect(sql).to eq(%(("topics"."id" > :id)))
      end
    end

    context "when every key sorts the same way" do
      let(:keys) do
        [
          JsonApiKit::Pagination::Keyset::Key.new(:created_at, model:),
          JsonApiKit::Pagination::Keyset::Key.new(:id, model:),
        ]
      end

      it "compares the keys row-wise, the form an index can seek on" do
        expect(sql).to eq(%(("topics"."created_at", "topics"."id") > (:created_at, :id)))
      end
    end

    context "with a nullable key whose cursor value is null" do
      let(:keys) do
        [
          JsonApiKit::Pagination::Keyset::Key.new(:created_at, model:),
          JsonApiKit::Pagination::Keyset::Key.new(
            :bumped_at,
            model:,
            direction: :desc,
            nulls: :last,
          ),
          JsonApiKit::Pagination::Keyset::Key.new(:id, model:),
        ]
      end
      let(:record) { Topic.new(id: 12, created_at: Time.utc(2026, 8, 3), bumped_at: nil) }

      it "tests the null with IS NULL, which an index can use" do
        expect(sql).to include(%("topics"."bumped_at" IS NULL))
      end

      it "leaves out the disjunct that no row could satisfy" do
        expect(sql).not_to include(%("topics"."bumped_at" <))
      end

      it "never reaches for null-safe equality" do
        expect(sql).not_to include("DISTINCT FROM")
      end
    end

    context "with a nullable key that does not lead" do
      let(:keys) do
        [
          JsonApiKit::Pagination::Keyset::Key.new(:created_at, model:),
          JsonApiKit::Pagination::Keyset::Key.new(:pinned_at, model:, nulls: :last),
          JsonApiKit::Pagination::Keyset::Key.new(:id, model:),
        ]
      end
      let(:record) do
        Topic.new(id: 12, created_at: Time.utc(2026, 8, 3), pinned_at: Time.utc(2026, 7, 1))
      end

      it "counts a row whose value is null as following one that has a value" do
        expect(sql).to include(%("topics"."pinned_at" IS NULL))
      end

      it "compares key by key, row-wise comparison dropping every null row" do
        expect(sql).not_to include(") > (")
      end
    end

    context "when a null cursor value's nulls sort first" do
      let(:keys) do
        [
          JsonApiKit::Pagination::Keyset::Key.new(:created_at, model:),
          JsonApiKit::Pagination::Keyset::Key.new(:pinned_at, model:, nulls: :first),
          JsonApiKit::Pagination::Keyset::Key.new(:id, model:),
        ]
      end
      let(:record) { Topic.new(id: 12, created_at: Time.utc(2026, 8, 3), pinned_at: nil) }

      it "counts a row that has a value as following the null" do
        expect(sql).to include(%("topics"."pinned_at" IS NOT NULL))
      end
    end

    context "with a boolean key whose cursor value is false" do
      let(:keys) do
        [
          JsonApiKit::Pagination::Keyset::Key.new(:closed, model:),
          JsonApiKit::Pagination::Keyset::Key.new(:id, model:, direction: :desc),
        ]
      end
      let(:record) { Topic.new(id: 12, closed: false) }

      it "compares the false value like any other" do
        expect(sql).to include(%("topics"."closed" = :closed))
      end

      it "does not take it for a value the cursor never held" do
        expect(sql).not_to include("IS NULL")
      end
    end

    context "when the leading key's cursor value is null" do
      let(:keys) do
        [
          JsonApiKit::Pagination::Keyset::Key.new(:bumped_at, model:),
          JsonApiKit::Pagination::Keyset::Key.new(:id, model:),
        ]
      end
      let(:record) { Topic.new(id: 12, bumped_at: nil) }

      it "drops the hint, which compared to null would match nothing at all" do
        expect(sql).to eq(%(("topics"."bumped_at" IS NULL AND "topics"."id" > :id)))
      end
    end
  end

  describe "#bindings" do
    subject(:bindings) { predicate.bindings }

    it "binds one value per key it compares, each named after its key" do
      expect(bindings.keys).to eq(%i[created_at id])
    end

    context "with a boolean key whose cursor value is false" do
      let(:keys) do
        [
          JsonApiKit::Pagination::Keyset::Key.new(:closed, model:),
          JsonApiKit::Pagination::Keyset::Key.new(:id, model:, direction: :desc),
        ]
      end
      let(:record) { Topic.new(id: 12, closed: false) }

      it "binds false, rather than dropping the bind as it would for a null" do
        expect(bindings).to have_key(:closed)
      end
    end

    context "with a nullable key whose cursor value is null" do
      let(:keys) do
        [
          JsonApiKit::Pagination::Keyset::Key.new(:created_at, model:),
          JsonApiKit::Pagination::Keyset::Key.new(:bumped_at, model:, nulls: :last),
          JsonApiKit::Pagination::Keyset::Key.new(:id, model:),
        ]
      end
      let(:record) { Topic.new(id: 12, created_at: Time.utc(2026, 8, 3), bumped_at: nil) }

      it "binds nothing for a key it never compares" do
        expect(bindings).not_to have_key(:bumped_at)
      end
    end
  end

  describe "#apply" do
    subject(:selected) { predicate.apply(scope).order(:id).map(&:id) }

    # One created_at, so the nullable key behind it is what orders these rows.
    fab!(:pinned_late) do
      Fabricate(:topic, created_at: Time.utc(2026, 8, 1), pinned_at: Time.utc(2026, 8, 2))
    end
    fab!(:pinned_early) do
      Fabricate(:topic, created_at: Time.utc(2026, 8, 1), pinned_at: Time.utc(2026, 8, 1))
    end
    fab!(:first_unpinned) { Fabricate(:topic, created_at: Time.utc(2026, 8, 1), pinned_at: nil) }
    fab!(:last_unpinned) { Fabricate(:topic, created_at: Time.utc(2026, 8, 1), pinned_at: nil) }

    let(:keys) do
      [
        JsonApiKit::Pagination::Keyset::Key.new(:created_at, model:),
        JsonApiKit::Pagination::Keyset::Key.new(:pinned_at, model:, direction: :desc, nulls: :last),
        JsonApiKit::Pagination::Keyset::Key.new(:id, model:),
      ]
    end
    let(:scope) do
      keyset.project(
        Topic.where(id: [pinned_late.id, pinned_early.id, first_unpinned.id, last_unpinned.id]),
      )
    end
    let(:record) { first_unpinned }

    it "walks on through the nulls from a row among them" do
      expect(selected).to eq([last_unpinned.id])
    end

    context "when the cursor names the last row of the order" do
      let(:record) { last_unpinned }

      it "selects nothing" do
        expect(selected).to be_empty
      end
    end

    context "when the cursor names a row that has a value" do
      let(:record) { pinned_late }

      it "selects the rows following it, those with no value among them" do
        expect(selected).to eq([pinned_early.id, first_unpinned.id, last_unpinned.id])
      end
    end
  end
end

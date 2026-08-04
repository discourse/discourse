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
          JsonApiKit::Pagination::Keyset::Key.new(
            :bumped_at,
            model:,
            direction: :desc,
            nulls_last: true,
          ),
          JsonApiKit::Pagination::Keyset::Key.new(:id, model:),
        ]
      end
      let(:record) { Topic.new(id: 12, bumped_at: nil) }

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

    it "binds a timestamp back to a time, to the microsecond" do
      expect(bindings[:created_at]).to eq(Time.utc(2026, 8, 3, 12, 0, 0, 123_456))
    end

    it "binds an integer column as an integer" do
      expect(bindings[:id]).to be(12)
    end

    context "with a key backed by SQL, which no column type describes" do
      let(:keys) do
        [
          JsonApiKit::Pagination::Keyset::Key.new(
            :author,
            model:,
            sql: "users.username",
            joins: [:user],
          ),
          JsonApiKit::Pagination::Keyset::Key.new(:id, model:),
        ]
      end
      let(:record) { Topic.new(id: 12).tap { it.define_singleton_method(:author) { "alice" } } }

      it "passes the value through untouched" do
        expect(bindings[:author]).to eq("alice")
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

      it "binds false, rather than dropping the bind as it would for a null" do
        expect(bindings).to have_key(:closed)
      end
    end

    context "with a nullable key whose cursor value is null" do
      let(:keys) do
        [
          JsonApiKit::Pagination::Keyset::Key.new(
            :bumped_at,
            model:,
            direction: :desc,
            nulls_last: true,
          ),
          JsonApiKit::Pagination::Keyset::Key.new(:id, model:),
        ]
      end
      let(:record) { Topic.new(id: 12, bumped_at: nil) }

      it "binds the null flag the order sorts on" do
        expect(bindings[:bumped_at_is_null]).to be(1)
      end

      it "binds nothing for a key it never compares" do
        expect(bindings).not_to have_key(:bumped_at)
      end
    end
  end

  describe "#apply" do
    subject(:selected) { predicate.apply(scope).order(:id).map(&:id) }

    fab!(:pinned) { Fabricate(:topic, pinned_at: Time.utc(2026, 8, 1)) }
    fab!(:first_unpinned, :topic)
    fab!(:last_unpinned, :topic)

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
    let(:scope) do
      keyset.project(Topic.where(id: [pinned.id, first_unpinned.id, last_unpinned.id]))
    end
    let(:record) { first_unpinned }

    it "walks into the null tail from a row inside it" do
      expect(selected).to eq([last_unpinned.id])
    end

    context "when the cursor names the last row of the order" do
      let(:record) { last_unpinned }

      it "selects nothing" do
        expect(selected).to be_empty
      end
    end

    context "when the cursor names a row before the null tail" do
      let(:record) { pinned }

      it "selects the whole tail" do
        expect(selected).to eq([first_unpinned.id, last_unpinned.id])
      end
    end
  end
end

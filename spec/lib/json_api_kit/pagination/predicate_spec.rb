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
    context "when the leading key can be null" do
      let(:keys) do
        [
          JsonApiKit::Pagination::Keyset::Key.new(:pinned_at, model:, nulls: :last),
          JsonApiKit::Pagination::Keyset::Key.new(:id, model:),
        ]
      end

      it "refuses to build the predicate" do
        expect { predicate }.to raise_error(ArgumentError)
      end
    end
  end

  describe "#sql" do
    subject(:sql) { predicate.sql }

    it "compares the keys one at a time" do
      expect(sql).to end_with(
        '(("topics"."created_at" = :created_at AND "topics"."id" > :id) ' \
          'OR ("topics"."created_at" < :created_at))',
      )
    end

    it "bounds the leading key at the cursor value" do
      expect(sql).to start_with(%("topics"."created_at" <= :created_at AND ))
    end

    context "when the order has one key" do
      let(:keys) { [JsonApiKit::Pagination::Keyset::Key.new(:id, model:)] }
      let(:record) { Topic.new(id: 12) }

      it "compares that key and adds no bound" do
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

      it "compares every key at once" do
        expect(sql).to eq(%(("topics"."created_at", "topics"."id") > (:created_at, :id)))
      end
    end

    context "when the cursor value of a nullable key is null" do
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

      it "matches the null with IS NULL" do
        expect(sql).to include(%("topics"."bumped_at" IS NULL))
      end

      it "leaves out a comparison that no row can satisfy" do
        expect(sql).not_to include(%("topics"."bumped_at" <))
      end
    end

    context "when a nullable key does not lead" do
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

      it "reads the null rows last" do
        expect(sql).to include(%("topics"."pinned_at" IS NULL))
      end

      it "does not compare every key at once" do
        expect(sql).not_to include(") > (")
      end
    end

    context "when the nulls of a null cursor value sort first" do
      let(:keys) do
        [
          JsonApiKit::Pagination::Keyset::Key.new(:created_at, model:),
          JsonApiKit::Pagination::Keyset::Key.new(:pinned_at, model:, nulls: :first),
          JsonApiKit::Pagination::Keyset::Key.new(:id, model:),
        ]
      end
      let(:record) { Topic.new(id: 12, created_at: Time.utc(2026, 8, 3), pinned_at: nil) }

      it "reads a row that holds a value after the null" do
        expect(sql).to include(%("topics"."pinned_at" IS NOT NULL))
      end
    end

    context "when the cursor value of a boolean key is false" do
      let(:keys) do
        [
          JsonApiKit::Pagination::Keyset::Key.new(:closed, model:),
          JsonApiKit::Pagination::Keyset::Key.new(:id, model:, direction: :desc),
        ]
      end
      let(:record) { Topic.new(id: 12, closed: false) }

      it "compares the false value like any other value" do
        expect(sql).to include(%("topics"."closed" = :closed))
      end
    end

    context "when the cursor value of the leading key is null" do
      let(:keys) do
        [
          JsonApiKit::Pagination::Keyset::Key.new(:bumped_at, model:),
          JsonApiKit::Pagination::Keyset::Key.new(:id, model:),
        ]
      end
      let(:record) { Topic.new(id: 12, bumped_at: nil) }

      it "moves past the null by the key behind it" do
        expect(sql).to eq(%(("topics"."bumped_at" IS NULL AND "topics"."id" > :id)))
      end
    end
  end

  describe "#bindings" do
    subject(:bindings) { predicate.bindings }

    it "returns one binding for each key" do
      expect(bindings.keys).to eq(%i[created_at id])
    end
  end

  describe "#apply" do
    subject(:selected_ids) { predicate.apply(scope).order(:id).map(&:id) }

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

    it "reads the next row that holds no value" do
      expect(selected_ids).to eq([last_unpinned.id])
    end

    context "when the cursor sits on the last row" do
      let(:record) { last_unpinned }

      it "reads no row" do
        expect(selected_ids).to be_empty
      end
    end

    context "when the cursor holds a value" do
      let(:record) { pinned_late }

      it "reads every later row, whether it holds a value or not" do
        expect(selected_ids).to eq([pinned_early.id, first_unpinned.id, last_unpinned.id])
      end
    end
  end
end

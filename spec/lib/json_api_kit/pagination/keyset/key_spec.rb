# frozen_string_literal: true

RSpec.describe JsonApiKit::Pagination::Keyset::Key do
  subject(:key) { described_class.new(:created_at, model:) }

  let(:model) { Topic }

  describe ".new" do
    context "with a direction that is not a direction" do
      it "refuses to build the key" do
        expect { described_class.new(:created_at, model:, direction: :sideways) }.to raise_error(
          ArgumentError,
        )
      end
    end

    context "with nulls sorted somewhere they cannot be" do
      it "refuses to build the key" do
        expect { described_class.new(:bumped_at, model:, nulls: :middle) }.to raise_error(
          ArgumentError,
        )
      end
    end
  end

  describe "#nullable?" do
    it "reads a column that always has a value" do
      expect(key).not_to be_nullable
    end

    context "when the key's value can be missing" do
      let(:key) { described_class.new(:bumped_at, model:, nulls: :last) }

      it "is a key the listing has to be segmented at" do
        expect(key).to be_nullable
      end
    end
  end

  describe "#direction" do
    subject(:direction) { key.direction }

    it "sorts ascending unless told otherwise" do
      expect(direction).to eq(:asc)
    end
  end

  describe "#projected?" do
    it "reads a plain column straight off the table" do
      expect(key).not_to be_projected
    end

    context "when the key is backed by SQL" do
      let(:key) { described_class.new(:username, model:, sql: "users.username") }

      it "has to be projected onto the scope" do
        expect(key).to be_projected
      end
    end
  end

  describe "#reverse" do
    subject(:reversed) { key.reverse }

    let(:key) do
      described_class.new(
        :username,
        model:,
        direction: :desc,
        sql: "users.username",
        joins: [:user],
      )
    end

    it "flips the direction" do
      expect(reversed.direction).to eq(:asc)
    end

    it "keeps the SQL backing the key" do
      expect(reversed.sql).to eq("users.username")
    end

    it "keeps the joins that SQL needs" do
      expect(reversed.joins).to contain_exactly(:user)
    end

    context "when the key is nullable" do
      let(:key) { described_class.new(:bumped_at, model:, nulls: :last) }

      it "is still nullable" do
        expect(reversed).to be_nullable
      end

      it "sends its nulls to the other end, where a backward scan of the index finds them" do
        expect(reversed.ordering.to_s).to eq(%("topics"."bumped_at" DESC NULLS FIRST))
      end
    end
  end

  describe "#value_for" do
    subject(:value) { key.value_for(record) }

    let(:record) { Topic.new(created_at: Time.utc(2026, 8, 3, 12)) }

    it "reads the value the key orders by" do
      expect(value).to eq(Time.utc(2026, 8, 3, 12))
    end
  end

  describe "#identifier" do
    subject(:identifier) { key.identifier }

    it "qualifies the column with its table" do
      expect(identifier).to eq(%("topics"."created_at"))
    end

    context "when the key is backed by SQL" do
      let(:key) { described_class.new(:username, model:, sql: "users.username") }

      it "names the key, not the SQL behind it — the SQL is gone once projected" do
        expect(identifier).to eq(%("topics"."username"))
      end
    end
  end

  describe "#value_sql" do
    subject(:value_sql) { key.value_sql }

    it "qualifies the column with its table" do
      expect(value_sql).to eq(%("topics"."created_at"))
    end

    context "when the key is backed by SQL" do
      let(:key) { described_class.new(:username, model:, sql: "users.username") }

      it "is that SQL" do
        expect(value_sql).to eq("users.username")
      end
    end
  end

  describe "#select_expression" do
    subject(:select_expression) { key.select_expression }

    it "has nothing to project" do
      expect(select_expression).to be_nil
    end

    context "when the key is backed by SQL" do
      let(:key) { described_class.new(:username, model:, sql: "users.username") }

      it "projects the SQL under the key's name" do
        expect(select_expression).to eq(%(users.username AS "username"))
      end
    end
  end

  describe "#valued_rows" do
    subject(:valued) { key.valued_rows.call(scope).map(&:id) }

    fab!(:pinned) { Fabricate(:topic, pinned_at: Time.utc(2026, 8, 1)) }
    fab!(:unpinned, :topic)

    let(:key) { described_class.new(:pinned_at, model:, nulls: :last) }
    let(:scope) { Topic.where(id: [pinned.id, unpinned.id]) }

    it "keeps the rows the key has a value in" do
      expect(valued).to contain_exactly(pinned.id)
    end
  end

  describe "#null_rows" do
    subject(:null) { key.null_rows.call(scope).map(&:id) }

    fab!(:pinned) { Fabricate(:topic, pinned_at: Time.utc(2026, 8, 1)) }
    fab!(:unpinned, :topic)

    let(:key) { described_class.new(:pinned_at, model:, nulls: :last) }
    let(:scope) { Topic.where(id: [pinned.id, unpinned.id]) }

    it "keeps the rows it has none in" do
      expect(null).to contain_exactly(unpinned.id)
    end
  end

  describe "#cast" do
    subject(:cast) { key.cast(value) }

    let(:value) { "2026-08-03T12:00:00.123456Z" }

    it "reads a timestamp back to the microsecond it was minted at" do
      expect(cast).to eq(Time.utc(2026, 8, 3, 12, 0, 0, 123_456))
    end

    context "with an integer column" do
      let(:key) { described_class.new(:id, model:) }
      let(:value) { "12" }

      it "reads it back as an integer" do
        expect(cast).to be(12)
      end
    end

    context "when the key is backed by SQL, which no column type describes" do
      let(:key) { described_class.new(:username, model:, sql: "users.username") }

      it "passes the value through untouched" do
        expect(cast).to eq("2026-08-03T12:00:00.123456Z")
      end
    end
  end

  describe "#ordering" do
    subject(:ordering) { key.ordering.to_s }

    it "orders by the column, ascending" do
      expect(ordering).to eq(%("topics"."created_at" ASC))
    end

    context "when the key sorts descending" do
      let(:key) { described_class.new(:created_at, model:, direction: :desc) }

      it "orders by it the other way" do
        expect(ordering).to eq(%("topics"."created_at" DESC))
      end
    end

    context "when the key is nullable" do
      let(:key) { described_class.new(:bumped_at, model:, direction: :desc, nulls: :last) }

      it "sends the nulls to the end, where an index for this order puts them" do
        expect(ordering).to eq(%("topics"."bumped_at" DESC NULLS LAST))
      end
    end
  end
end

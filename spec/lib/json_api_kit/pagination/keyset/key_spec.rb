# frozen_string_literal: true

RSpec.describe JsonApiKit::Pagination::Keyset::Key do
  subject(:key) { described_class.new(:created_at, model:) }

  let(:model) { Topic }

  it { is_expected.to delegate_method(:operator).to(:direction) }
  it { is_expected.to delegate_method(:trailing?).to(:nulls).with_prefix }
  it { is_expected.to delegate_method(:read_first?).to(:nulls).with_prefix }

  describe ".new" do
    context "when the direction is unknown" do
      it "refuses to build the key" do
        expect { described_class.new(:created_at, model:, direction: :sideways) }.to raise_error(
          ArgumentError,
        )
      end
    end

    context "when the nulls placement is unknown" do
      it "refuses to build the key" do
        expect { described_class.new(:bumped_at, model:, nulls: :middle) }.to raise_error(
          ArgumentError,
        )
      end
    end
  end

  describe "#nullable?" do
    context "when the nulls placement is nil" do
      it { is_expected.not_to be_nullable }
    end

    context "when the nulls placement is last" do
      subject(:key) { described_class.new(:bumped_at, model:, nulls: :last) }

      it { is_expected.to be_nullable }
    end
  end

  describe "#direction" do
    subject(:direction) { key.direction }

    context "when there is no direction" do
      it "sorts the key ascending" do
        expect(direction.to_sym).to eq(:asc)
      end
    end
  end

  describe "#without_nulls" do
    subject(:without_nulls) { key.without_nulls }

    let(:key) { described_class.new(:bumped_at, model:, direction: :desc, nulls: :last) }

    it "returns a key the database orders with no nulls placement" do
      expect(without_nulls.ordering.to_s).to eq(%("topics"."bumped_at" DESC))
    end

    it "keeps the direction of the key" do
      expect(without_nulls.direction.to_sym).to eq(:desc)
    end
  end

  describe "#projected?" do
    context "when the key carries no SQL" do
      it { is_expected.not_to be_projected }
    end

    context "when the key carries its own SQL" do
      subject(:key) { described_class.new(:username, model:, sql: "users.username") }

      it { is_expected.to be_projected }
    end
  end

  describe "#reverse" do
    subject(:reversed_key) { key.reverse }

    let(:key) do
      described_class.new(
        :username,
        model:,
        direction: :desc,
        sql: "users.username",
        joins: [:user],
      )
    end

    it "reverses the direction" do
      expect(reversed_key.direction.to_sym).to eq(:asc)
    end

    it "keeps the SQL of the key" do
      expect(reversed_key.sql).to eq("users.username")
    end

    it "keeps the joins its SQL needs" do
      expect(reversed_key.joins).to eq(JsonApiKit::Joins.for(:user))
    end

    context "when the key is nullable" do
      let(:key) { described_class.new(:bumped_at, model:, nulls: :last) }

      it { is_expected.to be_nullable }

      it "moves the nulls to the other end" do
        expect(reversed_key.ordering.to_s).to eq(%("topics"."bumped_at" DESC NULLS FIRST))
      end
    end
  end

  describe "#value_for" do
    subject(:value) { key.value_for(record) }

    let(:record) { Topic.new(created_at: Time.utc(2026, 8, 3, 12)) }

    it "returns the value the key orders by" do
      expect(value).to eq(Time.utc(2026, 8, 3, 12))
    end
  end

  describe "#named?" do
    it "matches its name as a symbol or a string" do
      expect(key).to be_named(:created_at).and be_named("created_at")
    end

    it { is_expected.not_to be_named(:id) }
  end

  describe "#to_s" do
    it "returns the name of the key" do
      expect(key.to_s).to eq("created_at")
    end
  end

  describe "#identifier" do
    subject(:identifier) { key.identifier }

    context "when the key carries no SQL" do
      it "quotes the column and its table" do
        expect(identifier).to eq(%("topics"."created_at"))
      end
    end

    context "when the key carries its own SQL" do
      let(:key) { described_class.new(:username, model:, sql: "users.username") }

      it "quotes the name of the key, not its SQL" do
        expect(identifier).to eq(%("topics"."username"))
      end
    end
  end

  describe "#value_sql" do
    subject(:value_sql) { key.value_sql }

    context "when the key carries no SQL" do
      it "quotes the column and its table" do
        expect(value_sql).to eq(%("topics"."created_at"))
      end
    end

    context "when the key carries its own SQL" do
      let(:key) { described_class.new(:username, model:, sql: "users.username") }

      it "returns that SQL" do
        expect(value_sql).to eq("users.username")
      end
    end
  end

  describe "#select_expression" do
    subject(:select_expression) { key.select_expression }

    context "when the key carries no SQL" do
      it "returns nil" do
        expect(select_expression).to be_nil
      end
    end

    context "when the key carries its own SQL" do
      let(:key) { described_class.new(:username, model:, sql: "users.username") }

      it "projects the SQL under the name of the key" do
        expect(select_expression).to eq(%(users.username AS "username"))
      end
    end
  end

  describe "#valued_condition" do
    subject(:valued_ids) { key.valued_condition.call(scope).map(&:id) }

    fab!(:pinned_topic) { Fabricate(:topic, pinned_at: Time.utc(2026, 8, 1)) }
    fab!(:unpinned, :topic)

    let(:key) { described_class.new(:pinned_at, model:, nulls: :last) }
    let(:scope) { Topic.where(id: [pinned_topic.id, unpinned.id]) }

    it "keeps the rows that hold a value for the key" do
      expect(valued_ids).to contain_exactly(pinned_topic.id)
    end

    context "with a joined column" do
      fab!(:section) { Fabricate(:category, name: "A section of the forum") }
      fab!(:filed) { Fabricate(:topic, category: section) }
      fab!(:unfiled, :private_message_topic)

      let(:key) do
        described_class.new(
          :category_name,
          model:,
          sql: "categories.name",
          joins: ["LEFT JOIN categories ON categories.id = topics.category_id"],
          nulls: :last,
        )
      end
      let(:scope) { Topic.where(id: [filed.id, unfiled.id]) }

      it "joins its table" do
        expect(valued_ids).to contain_exactly(filed.id)
      end
    end
  end

  describe "#null_condition" do
    subject(:null_ids) { key.null_condition.call(scope).map(&:id) }

    fab!(:pinned_topic) { Fabricate(:topic, pinned_at: Time.utc(2026, 8, 1)) }
    fab!(:unpinned, :topic)

    let(:key) { described_class.new(:pinned_at, model:, nulls: :last) }
    let(:scope) { Topic.where(id: [pinned_topic.id, unpinned.id]) }

    it "keeps the rows that hold no value for the key" do
      expect(null_ids).to contain_exactly(unpinned.id)
    end

    context "with a joined column" do
      fab!(:section) { Fabricate(:category, name: "A section of the forum") }
      fab!(:filed) { Fabricate(:topic, category: section) }
      fab!(:unfiled, :private_message_topic)

      let(:key) do
        described_class.new(
          :category_name,
          model:,
          sql: "categories.name",
          joins: ["LEFT JOIN categories ON categories.id = topics.category_id"],
          nulls: :last,
        )
      end
      let(:scope) { Topic.where(id: [filed.id, unfiled.id]) }

      it "joins its table" do
        expect(null_ids).to contain_exactly(unfiled.id)
      end
    end
  end

  describe "#at_or_after" do
    subject(:kept_ids) { key.at_or_after(scope, Time.utc(2026, 8, 2)).map(&:id) }

    fab!(:older) { Fabricate(:topic, created_at: Time.utc(2026, 8, 1)) }
    fab!(:newer) { Fabricate(:topic, created_at: Time.utc(2026, 8, 3)) }

    let(:scope) { Topic.where(id: [older.id, newer.id]) }

    context "when the key sorts ascending" do
      it "keeps the rows at or after the value" do
        expect(kept_ids).to contain_exactly(newer.id)
      end
    end

    context "when the key sorts descending" do
      let(:key) { described_class.new(:created_at, model:, direction: :desc) }

      it "keeps the rows at or before the value" do
        expect(kept_ids).to contain_exactly(older.id)
      end
    end

    context "when the key carries its own SQL" do
      subject(:kept_ids) { key.at_or_after(scope, "b").map(&:id) }

      fab!(:alice_topic) { Fabricate(:topic, user: Fabricate(:user, username: "alice")) }
      fab!(:carol_topic) { Fabricate(:topic, user: Fabricate(:user, username: "carol")) }

      let(:key) { described_class.new(:author, model:, sql: "users.username", joins: [:user]) }
      let(:scope) { Topic.where(id: [alice_topic.id, carol_topic.id]).joins(:user) }

      it "compares the SQL and not the column" do
        expect(kept_ids).to contain_exactly(carol_topic.id)
      end
    end
  end

  describe "#cast" do
    subject(:cast) { key.cast(value) }

    let(:value) { "2026-08-03T12:00:00.123456Z" }

    context "when the column holds a timestamp" do
      it "returns a time, to the microsecond" do
        expect(cast).to eq(Time.utc(2026, 8, 3, 12, 0, 0, 123_456))
      end
    end

    context "when the column holds an integer" do
      let(:key) { described_class.new(:id, model:) }
      let(:value) { "12" }

      it "returns an integer" do
        expect(cast).to be(12)
      end
    end

    context "when the model has no column of that name" do
      let(:key) { described_class.new(:username, model:, sql: "users.username") }

      it "returns the value with no change" do
        expect(cast).to eq("2026-08-03T12:00:00.123456Z")
      end
    end
  end

  describe "#ordering" do
    subject(:ordering) { key.ordering.to_s }

    context "when the key sorts ascending" do
      it "orders by the column, ascending" do
        expect(ordering).to eq(%("topics"."created_at" ASC))
      end
    end

    context "when the key sorts descending" do
      let(:key) { described_class.new(:created_at, model:, direction: :desc) }

      it "orders by the column, descending" do
        expect(ordering).to eq(%("topics"."created_at" DESC))
      end
    end

    context "when the nulls placement is last" do
      let(:key) { described_class.new(:bumped_at, model:, direction: :desc, nulls: :last) }

      it "orders the nulls at that end" do
        expect(ordering).to eq(%("topics"."bumped_at" DESC NULLS LAST))
      end
    end
  end
end

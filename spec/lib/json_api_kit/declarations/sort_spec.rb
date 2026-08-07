# frozen_string_literal: true

RSpec.describe JsonApiKit::Declarations::Sort do
  subject(:sort) { described_class.new(:created_at) }

  describe "#name" do
    subject(:name) { sort.name }

    it "is the name a client sorts by" do
      expect(name).to eq("created_at")
    end
  end

  describe "#key" do
    subject(:key) { sort.key(model: Topic, direction: :desc) }

    it "orders by the column the sort is named after" do
      expect(key.name).to eq(:created_at)
    end

    it "reads it the way the request asked for" do
      expect(key.direction.to_sym).to eq(:desc)
    end

    it "names no nulls placement for a column that always has a value" do
      expect(key).not_to be_nullable
    end

    context "when the column can be null" do
      subject(:sort) { described_class.new(:pinned_at) }

      it "sorts its nulls last, a page skipping them otherwise" do
        expect(key.ordering.to_s).to end_with("NULLS LAST")
      end
    end

    context "with a placement declared" do
      subject(:sort) { described_class.new(:pinned_at, nulls: :first) }

      it "sorts them where the declaration says" do
        expect(key.ordering.to_s).to end_with("NULLS FIRST")
      end
    end

    context "with the column named differently from the sort" do
      subject(:sort) { described_class.new(:ran_at, column: :last_posted_at) }

      it "orders by the column, the name being the client's own" do
        expect(key.name).to eq(:last_posted_at)
      end

      it "reads the column's nullability, not the name's" do
        expect(key.ordering.to_s).to end_with("NULLS LAST")
      end
    end

    context "with a value the table cannot hand over" do
      subject(:sort) do
        described_class.new(
          :author,
          sql: "users.username",
          joins: "LEFT JOIN users ON users.id = topics.user_id",
        )
      end

      it "orders by the SQL behind the sort" do
        expect(key.value_sql).to eq("users.username")
      end

      it "carries the joins that SQL needs" do
        expect(key.joins).to contain_exactly("LEFT JOIN users ON users.id = topics.user_id")
      end

      it "sorts its nulls last, no column saying whether it has any" do
        expect(key.ordering.to_s).to end_with("NULLS LAST")
      end
    end

    context "with a name a column cannot be called" do
      subject(:sort) { described_class.new("user.username", sql: "users.username") }

      it "projects the value under a name the scope can read it by" do
        expect(key.select_expression).to eq(%(users.username AS "user_username"))
      end
    end
  end
end

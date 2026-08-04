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
      let(:key) { described_class.new(:bumped_at, model:, nulls_last: true) }

      it "still wants its nulls last" do
        expect(reversed).to be_nulls_last
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

  describe "#expand" do
    subject(:expanded) { key.expand }

    it "contributes only itself to the order" do
      expect(expanded).to contain_exactly(key)
    end

    context "when the key is nullable" do
      let(:key) { described_class.new(:bumped_at, model:, direction: :desc, nulls_last: true) }

      it "puts a null flag in front of itself" do
        expect(expanded.map(&:name)).to eq(%i[bumped_at_is_null bumped_at])
      end

      it "keeps its own direction behind the flag" do
        expect(expanded.map(&:direction)).to eq(%i[asc desc])
      end

      it "asks for no second flag when expanded again" do
        expect(expanded.flat_map(&:expand).map(&:name)).to eq(%i[bumped_at_is_null bumped_at])
      end
    end
  end
end

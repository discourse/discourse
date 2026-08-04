# frozen_string_literal: true

RSpec.describe JsonApiKit::Pagination::Keyset::NullFlag do
  subject(:flag) { described_class.new(source) }

  let(:source) { JsonApiKit::Pagination::Keyset::Key.new(:bumped_at, model:) }
  let(:model) { Topic }

  describe "#name" do
    subject(:name) { flag.name }

    it "names itself after the key it flags" do
      expect(name).to eq(:bumped_at_is_null)
    end
  end

  describe "#direction" do
    subject(:direction) { flag.direction }

    it "sends the nulls to the end of the order" do
      expect(direction).to eq(:asc)
    end
  end

  describe "#projected?" do
    it "is computed, so it always has to be projected onto the scope" do
      expect(flag).to be_projected
    end
  end

  describe "#reverse" do
    subject(:reversed) { flag.reverse }

    it "brings the nulls first when the order is walked backwards" do
      expect(reversed.direction).to eq(:desc)
    end

    it "still flags the same key" do
      expect(reversed.name).to eq(:bumped_at_is_null)
    end
  end

  describe "#value_for" do
    subject(:value) { flag.value_for(record) }

    let(:record) { Topic.new(bumped_at: Time.utc(2026, 8, 3, 12)) }

    it "flags a value as present" do
      expect(value).to be(0)
    end

    context "with a null value" do
      let(:record) { Topic.new(bumped_at: nil) }

      it "flags it as null" do
        expect(value).to be(1)
      end
    end
  end

  describe "#value_sql" do
    subject(:value_sql) { flag.value_sql }

    it "tests the flagged column for null" do
      expect(value_sql).to eq(%(CASE WHEN "topics"."bumped_at" IS NULL THEN 1 ELSE 0 END))
    end

    context "when the flagged key is backed by SQL" do
      let(:source) do
        JsonApiKit::Pagination::Keyset::Key.new(:username, model:, sql: "users.username")
      end

      it "tests that SQL, which the key's alias could not stand in for" do
        expect(value_sql).to eq("CASE WHEN users.username IS NULL THEN 1 ELSE 0 END")
      end
    end
  end

  describe "#select_expression" do
    subject(:select_expression) { flag.select_expression }

    it "projects the flag under its own name" do
      expect(select_expression).to eq(
        %(CASE WHEN "topics"."bumped_at" IS NULL THEN 1 ELSE 0 END AS "bumped_at_is_null"),
      )
    end
  end

  describe "#expand" do
    subject(:expanded) { flag.expand }

    it "needs no flag of its own" do
      expect(expanded).to contain_exactly(flag)
    end
  end
end

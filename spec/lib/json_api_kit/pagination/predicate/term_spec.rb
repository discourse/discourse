# frozen_string_literal: true

RSpec.describe JsonApiKit::Pagination::Predicate::Term do
  subject(:term) { described_class.for(key, value) }

  let(:model) { Topic }
  let(:key) { JsonApiKit::Pagination::Keyset::Key.new(:created_at, model:) }
  let(:descending) do
    JsonApiKit::Pagination::Keyset::Key.new(:created_at, model:, direction: :desc)
  end
  let(:value) { "2026-08-03T12:00:00.123456Z" }

  describe ".for" do
    it "builds a term for a value the order can compare" do
      expect(term).to be_an_instance_of(described_class)
    end

    context "when the cursor holds no value for the key" do
      let(:value) { nil }

      it "builds the term that has nothing to compare" do
        expect(term).to be_an_instance_of(described_class::Null)
      end
    end

    context "when the cursor holds false for the key" do
      let(:key) { JsonApiKit::Pagination::Keyset::Key.new(:closed, model:) }
      let(:value) { false }

      it "compares it, false being a value a keyset can order by" do
        expect(term).to be_an_instance_of(described_class)
      end
    end
  end

  describe "#comparable?" do
    it "has a value for a comparison to hold against" do
      expect(term).to be_comparable
    end
  end

  describe "#operator" do
    subject(:operator) { term.operator }

    it "moves forward through an ascending key" do
      expect(operator).to eq(">")
    end

    context "when the key sorts descending" do
      let(:key) { descending }

      it "moves backward through it" do
        expect(operator).to eq("<")
      end
    end
  end

  describe "#placeholder" do
    subject(:placeholder) { term.placeholder }

    it "names the bind after the key" do
      expect(placeholder).to eq(":created_at")
    end
  end

  describe "#matches" do
    subject(:matches) { term.matches }

    it "holds the row at the cursor's value" do
      expect(matches).to eq(%("topics"."created_at" = :created_at))
    end
  end

  describe "#disjuncts" do
    subject(:disjuncts) { term.disjuncts(matched) }

    let(:matched) { [] }

    it "moves the row past the cursor" do
      expect(disjuncts).to eq([%(("topics"."created_at" > :created_at))])
    end

    context "with keys that matched the cursor before it" do
      let(:matched) do
        [described_class.for(JsonApiKit::Pagination::Keyset::Key.new(:id, model:), 12)]
      end

      it "holds those at the cursor and moves past its own" do
        expect(disjuncts).to eq([%(("topics"."id" = :id AND "topics"."created_at" > :created_at))])
      end
    end

    context "when the key sorts descending" do
      let(:key) { descending }

      it "moves the row the other way" do
        expect(disjuncts).to eq([%(("topics"."created_at" < :created_at))])
      end
    end
  end

  describe "#bound_on" do
    subject(:bounded) { term.bound_on("THE COMPARISON") }

    it "bounds it without excluding the cursor's own value" do
      expect(bounded).to eq(%("topics"."created_at" >= :created_at AND (THE COMPARISON)))
    end

    context "when the key sorts descending" do
      let(:key) { descending }

      it "bounds it the other way" do
        expect(bounded).to eq(%("topics"."created_at" <= :created_at AND (THE COMPARISON)))
      end
    end
  end

  describe "#bindings" do
    subject(:bindings) { term.bindings }

    it "casts the value back to what the column holds" do
      expect(bindings).to eq(created_at: Time.utc(2026, 8, 3, 12, 0, 0, 123_456))
    end
  end
end
